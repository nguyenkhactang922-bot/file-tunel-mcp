using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;

namespace FileMCP.Core;

public readonly record struct LogicalChatConnection(string ChatInstanceId, bool Resumed);

public sealed class LogicalChatCorrelationService
{
    public const string HandlePrefix = "chat_";
    private const int RandomBytes = 32;
    private readonly ConcurrentDictionary<string, byte> _knownHashes = new(StringComparer.Ordinal);

    public LogicalChatConnection Connect(string? chatInstanceId = null)
    {
        if (string.IsNullOrWhiteSpace(chatInstanceId))
        {
            while (true)
            {
                var handle = HandlePrefix + Base64Url(RandomNumberGenerator.GetBytes(RandomBytes));
                if (_knownHashes.TryAdd(Hash(handle), 0)) return new LogicalChatConnection(handle, false);
            }
        }

        var candidate = chatInstanceId.Trim();
        if (!IsValidHandle(candidate))
            throw new FileMcpException("Invalid FileMCP chat correlation handle.");
        if (!_knownHashes.ContainsKey(Hash(candidate)))
            throw new FileMcpException("Unknown FileMCP chat correlation handle. Call filemcp_observability_connect without chat_instance_id to establish a new correlation handle.");
        return new LogicalChatConnection(candidate, true);
    }

    public bool TryResolve(string? chatInstanceId, out string sessionHash)
    {
        sessionHash = "";
        if (string.IsNullOrWhiteSpace(chatInstanceId)) return false;
        var candidate = chatInstanceId.Trim();
        if (!IsValidHandle(candidate)) return false;
        var hash = Hash(candidate);
        if (!_knownHashes.ContainsKey(hash)) return false;
        sessionHash = hash;
        return true;
    }

    public static bool IsValidHandle(string value)
    {
        if (!value.StartsWith(HandlePrefix, StringComparison.Ordinal) || value.Length != HandlePrefix.Length + 43) return false;
        return value[HandlePrefix.Length..].All(ch => char.IsAsciiLetterOrDigit(ch) || ch is '-' or '_');
    }

    public static string HashForPersistence(string chatInstanceId)
    {
        if (!IsValidHandle(chatInstanceId)) throw new ArgumentException("Invalid FileMCP chat correlation handle.", nameof(chatInstanceId));
        return Hash(chatInstanceId);
    }

    private static string Hash(string value) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}