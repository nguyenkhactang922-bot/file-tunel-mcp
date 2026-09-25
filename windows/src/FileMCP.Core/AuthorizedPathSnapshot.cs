using Microsoft.Win32.SafeHandles;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace FileMCP.Core;

internal sealed record NativePathIdentity(
    uint VolumeSerialNumber,
    ulong FileIndex,
    bool IsDirectory,
    bool IsReparsePoint);

internal sealed record AuthorizedPathAncestor(string Path, NativePathIdentity Identity);

internal sealed record AuthorizedPathSnapshot(
    string RelativePath,
    string LexicalTargetPath,
    IReadOnlyList<AuthorizedPathAncestor> Ancestors,
    NativePathIdentity? TargetIdentity,
    bool ExpectedLeafAbsent);

internal sealed class AuthorizedPathSnapshotService
{
    private const uint FileShareRead = 0x00000001;
    private const uint FileShareWrite = 0x00000002;
    private const uint FileShareDelete = 0x00000004;
    private const uint OpenExisting = 3;
    private const uint FileFlagBackupSemantics = 0x02000000;
    private const uint FileFlagOpenReparsePoint = 0x00200000;
    private const int ErrorFileNotFound = 2;
    private const int ErrorPathNotFound = 3;

    private readonly SafePathResolver _resolver;

    public AuthorizedPathSnapshotService(SafePathResolver resolver)
    {
        _resolver = resolver;
    }

    public AuthorizedPathSnapshot CaptureExisting(string relativePath)
    {
        var lexicalTarget = LexicalTarget(relativePath);
        _ = _resolver.ResolveForDeletion(relativePath);
        var parent = RequireParent(lexicalTarget);
        var ancestors = CaptureAncestorChain(parent);
        var targetIdentity = CaptureIdentityRequired(lexicalTarget, allowReparsePoint: true, requireDirectory: null);
        return new AuthorizedPathSnapshot(relativePath, lexicalTarget, ancestors, targetIdentity, ExpectedLeafAbsent: false);
    }

    public AuthorizedPathSnapshot CaptureNewTarget(string relativePath)
    {
        var lexicalTarget = LexicalTarget(relativePath);
        _ = _resolver.Resolve(relativePath);
        var parent = RequireParent(lexicalTarget);
        var ancestors = CaptureAncestorChain(parent);
        if (TryCaptureIdentity(lexicalTarget, allowReparsePoint: true, requireDirectory: null) is not null)
            throw new FileMcpException("Mutation Guard expected the target leaf to be absent");
        return new AuthorizedPathSnapshot(relativePath, lexicalTarget, ancestors, TargetIdentity: null, ExpectedLeafAbsent: true);
    }

    public string Verify(AuthorizedPathSnapshot snapshot)
    {
        if (snapshot is null) throw new ArgumentNullException(nameof(snapshot));
        var lexicalTarget = LexicalTarget(snapshot.RelativePath);
        if (!PathEquals(lexicalTarget, snapshot.LexicalTargetPath))
            throw new FileMcpException("Mutation Guard target path changed since authorization");

        _ = _resolver.ResolveForDeletion(snapshot.RelativePath);
        var parent = RequireParent(lexicalTarget);
        var currentAncestors = CaptureAncestorChain(parent);
        if (currentAncestors.Count != snapshot.Ancestors.Count)
            throw new FileMcpException("Mutation Guard ancestor chain changed since authorization");
        for (var i = 0; i < currentAncestors.Count; i++)
        {
            var expected = snapshot.Ancestors[i];
            var current = currentAncestors[i];
            if (!PathEquals(expected.Path, current.Path) || expected.Identity != current.Identity)
                throw new FileMcpException("Mutation Guard ancestor identity changed since authorization");
        }

        var currentTarget = TryCaptureIdentity(lexicalTarget, allowReparsePoint: true, requireDirectory: null);
        if (snapshot.ExpectedLeafAbsent)
        {
            if (currentTarget is not null)
                throw new FileMcpException("Mutation Guard expected target leaf absence but an entry now exists");
        }
        else
        {
            if (snapshot.TargetIdentity is null)
                throw new FileMcpException("Mutation Guard snapshot is invalid: existing target identity is missing");
            if (currentTarget is null)
                throw new FileMcpException("Mutation Guard target disappeared since authorization");
            if (currentTarget != snapshot.TargetIdentity)
                throw new FileMcpException("Mutation Guard target identity changed since authorization");
        }
        return lexicalTarget;
    }

    private IReadOnlyList<AuthorizedPathAncestor> CaptureAncestorChain(string parentPath)
    {
        var root = Path.GetFullPath(_resolver.Root);
        var parent = Path.GetFullPath(parentPath);
        EnsureContainedLexically(parent);
        var result = new List<AuthorizedPathAncestor>();
        var current = root;
        var rootIdentity = CaptureIdentityRequired(current, allowReparsePoint: false, requireDirectory: true);
        result.Add(new AuthorizedPathAncestor(current, rootIdentity));
        if (PathEquals(parent, root)) return result;

        var relative = Path.GetRelativePath(root, parent);
        if (Path.IsPathRooted(relative) || relative.StartsWith(".." + Path.DirectorySeparatorChar, StringComparison.Ordinal) || relative == "..")
            throw new FileMcpException("Mutation Guard parent is outside the shared directory");
        foreach (var component in relative.Split([Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar], StringSplitOptions.RemoveEmptyEntries))
        {
            current = Path.GetFullPath(Path.Combine(current, component));
            var identity = CaptureIdentityRequired(current, allowReparsePoint: false, requireDirectory: true);
            result.Add(new AuthorizedPathAncestor(current, identity));
        }
        return result;
    }

    private string LexicalTarget(string relativePath)
    {
        var value = relativePath ?? "";
        if (Path.IsPathRooted(value) || value.StartsWith("\\\\", StringComparison.Ordinal))
            throw new FileMcpException("Mutation Guard refused a path outside the shared directory");
        var root = Path.GetFullPath(_resolver.Root);
        var lexical = Path.GetFullPath(Path.Combine(root, value));
        EnsureContainedLexically(lexical);
        if (PathEquals(lexical, root))
            throw new FileMcpException("Mutation Guard does not authorize the shared root as a mutation target");
        return lexical;
    }

    private void EnsureContainedLexically(string path)
    {
        var root = TrimForComparison(Path.GetFullPath(_resolver.Root));
        var full = TrimForComparison(Path.GetFullPath(path));
        if (string.Equals(root, full, StringComparison.OrdinalIgnoreCase)) return;
        var prefix = root + Path.DirectorySeparatorChar;
        if (!full.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            throw new FileMcpException("Mutation Guard refused a path outside the shared directory");
    }

    private static string RequireParent(string path) =>
        Path.GetDirectoryName(path) ?? throw new FileMcpException("Mutation Guard target parent is unavailable");

    private static NativePathIdentity CaptureIdentityRequired(string path, bool allowReparsePoint, bool? requireDirectory)
    {
        return TryCaptureIdentity(path, allowReparsePoint, requireDirectory)
            ?? throw new FileMcpException($"Mutation Guard path disappeared: {Path.GetFileName(path)}");
    }

    private static NativePathIdentity? TryCaptureIdentity(string path, bool allowReparsePoint, bool? requireDirectory)
    {
        using var handle = CreateFileW(
            path,
            0,
            FileShareRead | FileShareWrite | FileShareDelete,
            IntPtr.Zero,
            OpenExisting,
            FileFlagBackupSemantics | FileFlagOpenReparsePoint,
            IntPtr.Zero);
        if (handle.IsInvalid)
        {
            var error = Marshal.GetLastWin32Error();
            if (error is ErrorFileNotFound or ErrorPathNotFound) return null;
            throw new Win32Exception(error, $"Mutation Guard could not inspect path: {path}");
        }
        if (!GetFileInformationByHandle(handle, out var info))
            throw new Win32Exception(Marshal.GetLastWin32Error(), $"Mutation Guard could not read native path identity: {path}");

        var attributes = (FileAttributes)info.FileAttributes;
        var isDirectory = (attributes & FileAttributes.Directory) != 0;
        var isReparsePoint = (attributes & FileAttributes.ReparsePoint) != 0;
        if (isReparsePoint && !allowReparsePoint)
            throw new FileMcpException("Mutation Guard refused an ancestor reparse point or junction");
        if (requireDirectory is true && !isDirectory)
            throw new FileMcpException("Mutation Guard ancestor is not a directory");
        if (requireDirectory is false && isDirectory)
            throw new FileMcpException("Mutation Guard expected a non-directory target");

        var index = (ulong)info.FileIndexHigh << 32 | info.FileIndexLow;
        return new NativePathIdentity(info.VolumeSerialNumber, index, isDirectory, isReparsePoint);
    }

    private static bool PathEquals(string lhs, string rhs) =>
        string.Equals(TrimForComparison(Path.GetFullPath(lhs)), TrimForComparison(Path.GetFullPath(rhs)), StringComparison.OrdinalIgnoreCase);

    private static string TrimForComparison(string path) => path.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);

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

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(
        string fileName,
        uint desiredAccess,
        uint shareMode,
        IntPtr securityAttributes,
        uint creationDisposition,
        uint flagsAndAttributes,
        IntPtr templateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFileInformationByHandle(SafeFileHandle file, out ByHandleFileInformation information);
}
