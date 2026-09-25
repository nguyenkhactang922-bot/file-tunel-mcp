using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed class AuthenticatedCursorCodec
{
    public const string CursorMetadataKey = "io.filemcp/cursor";
    public static readonly TimeSpan DefaultMaxLifetime = TimeSpan.FromMinutes(15);
    private const int MaxEncodedCursorChars = 4096;
    private const int MaxPayloadBytes = 2048;
    private readonly byte[] _key;
    private readonly Func<DateTimeOffset> _clock;
    private readonly TimeSpan _maxLifetime;

    public AuthenticatedCursorCodec(byte[]? key = null, Func<DateTimeOffset>? clock = null, TimeSpan? maxLifetime = null)
    {
        _key = key is null ? RandomNumberGenerator.GetBytes(32) : key.ToArray();
        if (_key.Length < 32) throw new ArgumentException("Cursor key must be at least 32 bytes", nameof(key));
        _clock = clock ?? (() => DateTimeOffset.UtcNow);
        _maxLifetime = maxLifetime ?? DefaultMaxLifetime;
        if (_maxLifetime <= TimeSpan.Zero || _maxLifetime > TimeSpan.FromHours(1))
            throw new ArgumentOutOfRangeException(nameof(maxLifetime), "Cursor max lifetime must be positive and no more than one hour");
    }

    public string Encode(string tool, string optionsHash, string rootAuthorityId, long generation, string position, DateTimeOffset expiresAt)
    {
        ValidateBoundString(tool, nameof(tool), 128);
        ValidateBoundString(optionsHash, nameof(optionsHash), 256);
        ValidateBoundString(rootAuthorityId, nameof(rootAuthorityId), 512);
        ValidateBoundString(position, nameof(position), 1024);
        if (generation < 0) throw new ArgumentOutOfRangeException(nameof(generation));

        var now = _clock().ToUniversalTime();
        var expiry = expiresAt.ToUniversalTime();
        if (expiry <= now || expiry - now > _maxLifetime)
            throw new FileMcpException($"Cursor expiry must be within {_maxLifetime.TotalMinutes:0} minutes");

        var payload = new JsonObject
        {
            ["v"] = 1,
            ["tool"] = tool,
            ["optionsHash"] = optionsHash,
            ["rootAuthorityId"] = rootAuthorityId,
            ["generation"] = generation,
            ["position"] = position,
            ["expiresUnixMs"] = expiry.ToUnixTimeMilliseconds(),
        }.ToJsonString(new JsonSerializerOptions { WriteIndented = false });
        var payloadBytes = Encoding.UTF8.GetBytes(payload);
        if (payloadBytes.Length > MaxPayloadBytes) throw new FileMcpException("Cursor payload is too large");

        using var hmac = new HMACSHA256(_key);
        var signature = hmac.ComputeHash(payloadBytes);
        return Base64Url(payloadBytes) + "." + Base64Url(signature);
    }

    public string Decode(
        string cursor,
        string expectedTool,
        string expectedOptionsHash,
        string expectedRootAuthorityId,
        long expectedGeneration,
        DateTimeOffset now)
    {
        if (string.IsNullOrWhiteSpace(cursor) || cursor.Length > MaxEncodedCursorChars)
            throw new FileMcpException("Malformed cursor");

        var parts = cursor.Split('.', StringSplitOptions.None);
        if (parts.Length != 2) throw new FileMcpException("Malformed cursor");

        byte[] payloadBytes;
        byte[] signature;
        try
        {
            payloadBytes = FromBase64Url(parts[0]);
            signature = FromBase64Url(parts[1]);
        }
        catch
        {
            throw new FileMcpException("Malformed cursor");
        }

        if (payloadBytes.Length is <= 0 or > MaxPayloadBytes || signature.Length != 32)
            throw new FileMcpException("Malformed cursor");

        using var hmac = new HMACSHA256(_key);
        var expectedSignature = hmac.ComputeHash(payloadBytes);
        if (!CryptographicOperations.FixedTimeEquals(signature, expectedSignature))
            throw new FileMcpException("Cursor authentication failed");

        JsonObject payload;
        try
        {
            payload = JsonNode.Parse(payloadBytes) as JsonObject ?? throw new JsonException();
            if (payload["v"] is not JsonValue versionNode || !versionNode.TryGetValue<int>(out var version) || version != 1)
                throw new FileMcpException("Unsupported cursor version");
            if (!TryString(payload, "tool", out var tool) || tool != expectedTool) throw new FileMcpException("Cursor tool mismatch");
            if (!TryString(payload, "optionsHash", out var optionsHash) || optionsHash != expectedOptionsHash) throw new FileMcpException("Cursor options mismatch");
            if (!TryString(payload, "rootAuthorityId", out var rootAuthorityId) || rootAuthorityId != expectedRootAuthorityId) throw new FileMcpException("Cursor root mismatch");
            if (payload["generation"] is not JsonValue generationNode || !generationNode.TryGetValue<long>(out var generation) || generation != expectedGeneration)
                throw new FileMcpException("Cursor generation is stale");
            if (payload["expiresUnixMs"] is not JsonValue expiryNode || !expiryNode.TryGetValue<long>(out var expiry) || now.ToUniversalTime().ToUnixTimeMilliseconds() >= expiry)
                throw new FileMcpException("Cursor expired");
            if (!TryString(payload, "position", out var position) || string.IsNullOrEmpty(position)) throw new FileMcpException("Cursor position missing");
            return position;
        }
        catch (FileMcpException)
        {
            throw;
        }
        catch
        {
            throw new FileMcpException("Malformed cursor payload");
        }
    }

    public static string StableHash(string value) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

    private static bool TryString(JsonObject payload, string key, out string value)
    {
        value = "";
        if (payload[key] is not JsonValue node || !node.TryGetValue<string>(out var parsed) || parsed is null) return false;
        value = parsed;
        return true;
    }

    private static void ValidateBoundString(string value, string name, int maxChars)
    {
        if (string.IsNullOrEmpty(value) || value.Length > maxChars)
            throw new ArgumentException($"{name} must contain 1..{maxChars} characters", name);
    }

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] FromBase64Url(string value)
    {
        if (value.Length == 0 || value.Length > MaxEncodedCursorChars) throw new FormatException();
        var padded = value.Replace('-', '+').Replace('_', '/');
        padded += new string('=', (4 - padded.Length % 4) % 4);
        return Convert.FromBase64String(padded);
    }
}
