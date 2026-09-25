using Microsoft.Win32.SafeHandles;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace FileMCP.Core;

internal sealed record FileVersionedRead(
    byte[] Data,
    string VersionToken,
    string VersionFingerprint,
    long SizeBytes,
    string ContentHash,
    string PathFingerprint);

internal sealed record FileVersionPayload(
    int Schema,
    string PathFingerprint,
    string IdentityFingerprint,
    string EntryType,
    long SizeBytes,
    long ModifiedAt100Ns,
    string Strength,
    string ContentHash);

internal sealed class FileVersionService
{
    public const int TokenSchemaVersion = 1;
    public const string ProviderVersion = "file-version-v1";
    private const int MaxEncodedTokenChars = 4096;
    private const int MaxPayloadBytes = 2048;
    private const int HashChunkBytes = 64 * 1024;
    private static readonly byte[] ProcessSigningKey = RandomNumberGenerator.GetBytes(32);
    private readonly SafePathResolver _resolver;
    private readonly byte[] _key;
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };

    public FileVersionService(SafePathResolver resolver, byte[]? key = null)
    {
        _resolver = resolver;
        _key = key is null ? ProcessSigningKey : key.ToArray();
        if (_key.Length < 32) throw new ArgumentException("File version signing key must be at least 32 bytes", nameof(key));
    }

    public FileVersionedRead ReadVersioned(string relativePath, int maxBytes)
    {
        if (maxBytes < 1) throw new ArgumentOutOfRangeException(nameof(maxBytes));
        var target = _resolver.Resolve(relativePath);
        using var stream = new FileStream(target, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, HashChunkBytes, FileOptions.SequentialScan);
        var before = Snapshot(stream.SafeFileHandle);
        if (!string.Equals(before.EntryType, "file", StringComparison.Ordinal))
            throw new FileMcpException($"No such file: {relativePath}");
        if (before.SizeBytes > maxBytes)
            throw new FileMcpException("File is larger than the 5 MB limit for this tool");

        using var buffer = new MemoryStream((int)Math.Min(before.SizeBytes, maxBytes));
        var chunk = new byte[HashChunkBytes];
        while (true)
        {
            var read = stream.Read(chunk, 0, chunk.Length);
            if (read == 0) break;
            if (buffer.Length + read > maxBytes)
                throw new FileMcpException("File is larger than the 5 MB limit for this tool");
            buffer.Write(chunk, 0, read);
        }
        var data = buffer.ToArray();
        var after = SnapshotPath(target);
        EnsureUnchanged(before, after);
        if (data.LongLength != before.SizeBytes)
            throw new FileMcpException("File changed while its strong version was being captured");

        var canonicalRelative = _resolver.RelativePath(target);
        var contentHash = Sha256Tagged(data);
        var payload = new FileVersionPayload(
            TokenSchemaVersion,
            FingerprintPath(target, canonicalRelative),
            before.IdentityFingerprint,
            before.EntryType,
            before.SizeBytes,
            before.ModifiedAt100Ns,
            "content",
            contentHash);
        var payloadBytes = JsonSerializer.SerializeToUtf8Bytes(payload, JsonOptions);
        return new FileVersionedRead(
            data,
            Encode(payload, payloadBytes),
            Sha256Tagged(payloadBytes),
            before.SizeBytes,
            contentHash,
            payload.PathFingerprint);
    }

    public FileVersionPayload VerifyExpectedVersion(string relativePath, string token, int maxBytes = FileMcpConstants.MaxFileBytes)
    {
        var expected = Decode(token);
        var currentRead = ReadVersioned(relativePath, maxBytes);
        var current = Decode(currentRead.VersionToken);
        if (!string.Equals(current.PathFingerprint, expected.PathFingerprint, StringComparison.Ordinal))
            throw new FileMcpException("Version token belongs to a different path or scope");
        if (!string.Equals(current.IdentityFingerprint, expected.IdentityFingerprint, StringComparison.Ordinal))
            throw new FileMcpException("Target was replaced since the version token was captured");
        if (current != expected)
            throw new FileMcpException("File changed since the version token was captured");
        return current;
    }

    internal FileVersionPayload DecodeForTest(string token) => Decode(token);

    internal static string Sha256Tagged(ReadOnlySpan<byte> bytes) =>
        "sha256:" + Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();

    internal static string Sha256Tagged(string value) => Sha256Tagged(Encoding.UTF8.GetBytes(value));

    private string FingerprintPath(string target, string canonicalRelative)
    {
        var canonical = OperatingSystem.IsWindows()
            ? Path.GetFullPath(target).ToUpperInvariant()
            : Path.GetFullPath(target);
        return Sha256Tagged(_resolver.Root + "\0" + canonicalRelative + "\0" + canonical);
    }

    private string Encode(FileVersionPayload payload, byte[]? serialized = null)
    {
        var bytes = serialized ?? JsonSerializer.SerializeToUtf8Bytes(payload, JsonOptions);
        if (bytes.Length > MaxPayloadBytes) throw new FileMcpException("File version payload is too large");
        var encoded = Base64Url(bytes);
        using var hmac = new HMACSHA256(_key);
        var signature = Base64Url(hmac.ComputeHash(Encoding.ASCII.GetBytes(encoded)));
        return $"v{TokenSchemaVersion}:{encoded}:{signature}";
    }

    private FileVersionPayload Decode(string token)
    {
        if (string.IsNullOrWhiteSpace(token) || token.Length > MaxEncodedTokenChars)
            throw new FileMcpException("Unsupported or malformed file version token");
        var parts = token.Split(':', StringSplitOptions.None);
        if (parts.Length != 3 || parts[0] != $"v{TokenSchemaVersion}")
            throw new FileMcpException("Unsupported or malformed file version token");
        byte[] payloadBytes;
        byte[] signature;
        try
        {
            payloadBytes = FromBase64Url(parts[1]);
            signature = FromBase64Url(parts[2]);
        }
        catch
        {
            throw new FileMcpException("Unsupported or malformed file version token");
        }
        if (payloadBytes.Length is <= 0 or > MaxPayloadBytes || signature.Length != 32)
            throw new FileMcpException("Unsupported or malformed file version token");
        using var hmac = new HMACSHA256(_key);
        var expected = hmac.ComputeHash(Encoding.ASCII.GetBytes(parts[1]));
        if (!CryptographicOperations.FixedTimeEquals(signature, expected))
            throw new FileMcpException("File version token authentication failed");
        try
        {
            var decoded = JsonSerializer.Deserialize<FileVersionPayload>(payloadBytes, JsonOptions)
                ?? throw new JsonException();
            if (decoded.Schema != TokenSchemaVersion || decoded.Strength != "content" ||
                string.IsNullOrWhiteSpace(decoded.PathFingerprint) || string.IsNullOrWhiteSpace(decoded.IdentityFingerprint) ||
                string.IsNullOrWhiteSpace(decoded.ContentHash) || decoded.SizeBytes < 0)
                throw new JsonException();
            return decoded;
        }
        catch
        {
            throw new FileMcpException("Unsupported or malformed file version payload");
        }
    }

    private static FileSnapshot SnapshotPath(string path)
    {
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 1, FileOptions.None);
        return Snapshot(stream.SafeFileHandle);
    }

    private static FileSnapshot Snapshot(SafeFileHandle handle)
    {
        if (!GetFileInformationByHandle(handle, out var info))
            throw new FileMcpException("Could not read native file identity: " + Marshal.GetLastWin32Error());
        var attributes = (FileAttributes)info.FileAttributes;
        var entryType = (attributes & FileAttributes.Directory) != 0 ? "directory" : "file";
        var size = ((long)info.FileSizeHigh << 32) | info.FileSizeLow;
        var modified = ((long)info.LastWriteTime.High << 32) | info.LastWriteTime.Low;
        var index = ((ulong)info.FileIndexHigh << 32) | info.FileIndexLow;
        Span<byte> identityBytes = stackalloc byte[12];
        BitConverter.TryWriteBytes(identityBytes[..4], info.VolumeSerialNumber);
        BitConverter.TryWriteBytes(identityBytes[4..], index);
        return new FileSnapshot(
            Sha256Tagged(identityBytes),
            entryType,
            size,
            modified);
    }

    private static void EnsureUnchanged(FileSnapshot before, FileSnapshot after)
    {
        if (before != after)
            throw new FileMcpException("File changed while its strong version was being captured");
    }

    private static string Base64Url(ReadOnlySpan<byte> bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] FromBase64Url(string value)
    {
        if (value.Length == 0 || value.Length > MaxEncodedTokenChars) throw new FormatException();
        var padded = value.Replace('-', '+').Replace('_', '/');
        padded += new string('=', (4 - padded.Length % 4) % 4);
        return Convert.FromBase64String(padded);
    }

    private sealed record FileSnapshot(string IdentityFingerprint, string EntryType, long SizeBytes, long ModifiedAt100Ns);

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeFileTime
    {
        public uint Low;
        public uint High;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct ByHandleFileInformation
    {
        public uint FileAttributes;
        public NativeFileTime CreationTime;
        public NativeFileTime LastAccessTime;
        public NativeFileTime LastWriteTime;
        public uint VolumeSerialNumber;
        public uint FileSizeHigh;
        public uint FileSizeLow;
        public uint NumberOfLinks;
        public uint FileIndexHigh;
        public uint FileIndexLow;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFileInformationByHandle(SafeFileHandle file, out ByHandleFileInformation information);
}
