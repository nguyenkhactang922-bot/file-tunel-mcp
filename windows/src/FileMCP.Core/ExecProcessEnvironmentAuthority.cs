using System.Collections;
using System.Text.RegularExpressions;

namespace FileMCP.Core;

internal sealed class ExecProcessEnvironmentAuthority
{
    public const int MaxPatterns = 32;
    public const int MaxOverrides = 32;
    public const int MaxNameChars = 128;
    public const int MaxValueChars = 8_192;
    public const int MaxTotalOverrideChars = 16_384;
    public const int MaxForwardedVariables = 64;
    public const int MaxForwardedValueChars = 16_384;
    public const int MaxEnvironmentChars = 32_000;

    private static readonly string[] MinimalBaselineNames =
    [
        "PATH", "PATHEXT", "SystemRoot", "WINDIR", "TEMP", "TMP",
        "USERPROFILE", "HOMEDRIVE", "HOMEPATH", "APPDATA", "LOCALAPPDATA",
        "LANG", "LC_ALL", "LC_CTYPE",
    ];

    private static readonly string[] SecretMarkers =
    [
        "TOKEN", "SECRET", "PASSWORD", "PASSWD", "API_KEY", "APIKEY",
        "PRIVATE_KEY", "ACCESS_KEY", "CLIENT_SECRET", "CREDENTIAL", "BEARER", "COOKIE",
    ];

    private readonly IReadOnlyList<string> _patterns;

    public ExecProcessEnvironmentAuthority(IEnumerable<string>? patterns = null)
    {
        _patterns = NormalizePatterns(patterns);
    }

    public IReadOnlyList<string> Patterns => _patterns;

    public static List<string> NormalizePatterns(IEnumerable<string>? patterns)
    {
        var result = new List<string>();
        foreach (var raw in patterns ?? [])
        {
            var pattern = (raw ?? "").Trim();
            if (pattern.Length == 0) continue;
            ValidatePattern(pattern);
            if (!result.Contains(pattern, StringComparer.OrdinalIgnoreCase)) result.Add(pattern);
            if (result.Count > MaxPatterns) throw new FileMcpException($"exec_process environment allowlist supports at most {MaxPatterns} entries");
        }
        return result;
    }

    public Dictionary<string, string> Build(IReadOnlyDictionary<string, string>? requestOverrides = null)
    {
        var host = Environment.GetEnvironmentVariables().Cast<DictionaryEntry>()
            .ToDictionary(item => (string)item.Key, item => (string?)item.Value ?? "", StringComparer.OrdinalIgnoreCase);
        return BuildCore(host, requestOverrides);
    }

    internal Dictionary<string, string> BuildForTest(
        IReadOnlyDictionary<string, string> host,
        IReadOnlyDictionary<string, string>? requestOverrides = null) => BuildCore(host, requestOverrides);

    private Dictionary<string, string> BuildCore(
        IReadOnlyDictionary<string, string> host,
        IReadOnlyDictionary<string, string>? requestOverrides)
    {
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var environmentChars = 0;

        void SetBounded(string name, string value)
        {
            if (value.Length > MaxForwardedValueChars)
                throw new FileMcpException($"Environment variable {name} exceeds {MaxForwardedValueChars} characters");
            var replacing = result.TryGetValue(name, out var previous);
            var previousChars = replacing ? name.Length + previous!.Length : 0;
            if (!replacing && result.Count >= MaxForwardedVariables)
                throw new FileMcpException($"exec_process environment exceeds {MaxForwardedVariables} forwarded variables");
            var nextChars = checked(environmentChars - previousChars + name.Length + value.Length);
            if (nextChars > MaxEnvironmentChars)
                throw new FileMcpException($"exec_process environment exceeds {MaxEnvironmentChars} total characters");
            result[name] = value;
            environmentChars = nextChars;
        }

        foreach (var name in MinimalBaselineNames)
            if (host.TryGetValue(name, out var value) && value.Length > 0) SetBounded(name, value);

        foreach (var pair in host)
        {
            var matching = MatchingPattern(pair.Key);
            if (matching is null) continue;
            if (IsSecretLike(pair.Key) && ContainsWildcard(matching)) continue;
            SetBounded(pair.Key, pair.Value);
        }

        if (requestOverrides is null) return result;
        if (requestOverrides.Count > MaxOverrides) throw new FileMcpException($"exec_process environment supports at most {MaxOverrides} overrides");
        var totalChars = 0;
        foreach (var pair in requestOverrides)
        {
            ValidateName(pair.Key);
            if (pair.Value.Contains('\0')) throw new FileMcpException($"Environment override {pair.Key} contains a NUL byte");
            if (pair.Value.Length > MaxValueChars) throw new FileMcpException($"Environment override {pair.Key} exceeds {MaxValueChars} characters");
            totalChars = checked(totalChars + pair.Key.Length + pair.Value.Length);
            if (totalChars > MaxTotalOverrideChars) throw new FileMcpException("exec_process environment overrides exceed the total size limit");

            var matching = MatchingPattern(pair.Key);
            if (matching is null) throw new FileMcpException($"Environment override is not locally allowed: {pair.Key}");
            if (IsSecretLike(pair.Key) && ContainsWildcard(matching))
                throw new FileMcpException($"Secret-like environment override requires an exact local allowlist entry: {pair.Key}");
            SetBounded(pair.Key, pair.Value);
        }
        return result;
    }

    internal static bool IsSecretLike(string name)
    {
        var upper = name.ToUpperInvariant();
        return SecretMarkers.Any(marker => upper.Contains(marker, StringComparison.Ordinal));
    }

    private string? MatchingPattern(string name) => _patterns.FirstOrDefault(pattern => GlobMatches(pattern, name));
    private static bool ContainsWildcard(string pattern) => pattern.Contains('*') || pattern.Contains('?');

    private static bool GlobMatches(string pattern, string value)
    {
        var regex = "^" + Regex.Escape(pattern).Replace("\\*", ".*").Replace("\\?", ".") + "$";
        return Regex.IsMatch(value, regex, RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);
    }

    private static void ValidatePattern(string pattern)
    {
        if (pattern.Length > MaxNameChars || pattern.Contains('\0') || pattern.Contains('=') ||
            pattern.Any(char.IsWhiteSpace) || !pattern.All(ch => char.IsAsciiLetterOrDigit(ch) || ch is '_' or '.' or '-' or '*' or '?'))
            throw new FileMcpException($"Invalid exec_process environment allowlist pattern: {pattern}");
    }

    private static void ValidateName(string name)
    {
        if (string.IsNullOrEmpty(name) || name.Length > MaxNameChars || name.Contains('\0') || name.Contains('=') ||
            !(char.IsAsciiLetter(name[0]) || name[0] == '_') || name.Skip(1).Any(ch => !(char.IsAsciiLetterOrDigit(ch) || ch == '_')))
            throw new FileMcpException($"Invalid environment variable name: {name}");
    }
}
