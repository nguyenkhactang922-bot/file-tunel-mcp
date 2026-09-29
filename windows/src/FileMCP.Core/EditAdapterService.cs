using System.Text;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace FileMCP.Core;

internal sealed record EditAdapterCompilation(
    JsonArray Edits,
    int MatchCount,
    int HunkCount);

internal sealed class EditAdapterService
{
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);
    private static readonly Regex HunkHeader = new(
        @"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(?: .*)?$",
        RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private readonly FileVersionService _versions;

    public EditAdapterService(FileVersionService versions)
    {
        _versions = versions;
    }

    public EditAdapterCompilation CompileSearchReplace(
        string relativePath,
        string expectedVersion,
        string search,
        string replacement,
        CancellationToken cancellationToken,
        ToolExecutionContext? context)
    {
        if (string.IsNullOrWhiteSpace(expectedVersion))
            throw new FileMcpException("expected_version must not be empty");
        if (string.IsNullOrEmpty(search))
            throw new FileMcpException("search must not be empty");
        RequireContinue(cancellationToken, context, "apply_search_replace cancelled before compile");

        var source = _versions.ReadExpectedVersioned(relativePath, expectedVersion);
        if (context is not null && !context.TryScanFile(source.SizeBytes))
            throw new FileMcpException("apply_search_replace budget exhausted while reading source");

        var content = ContentWithoutBom(source.Data);
        ValidateUtf8(content, "apply_search_replace requires valid UTF-8 source text");
        var needle = Encoding.UTF8.GetBytes(search);
        var matches = FindAll(content, needle, cancellationToken, context);
        if (matches.Count == 0)
            throw new FileMcpException("apply_search_replace search text matched zero locations");
        if (matches.Count != 1)
            throw new FileMcpException($"apply_search_replace search text is ambiguous: matched {matches.Count} locations");

        var start = matches[0];
        var edit = new JsonObject
        {
            ["start_byte"] = start,
            ["end_byte"] = checked(start + needle.Length),
            ["replacement"] = replacement,
        };
        return new EditAdapterCompilation(new JsonArray(edit), matches.Count, 0);
    }

    public EditAdapterCompilation CompileUnifiedDiff(
        string relativePath,
        string expectedVersion,
        string unifiedDiff,
        CancellationToken cancellationToken,
        ToolExecutionContext? context)
    {
        if (string.IsNullOrWhiteSpace(expectedVersion))
            throw new FileMcpException("expected_version must not be empty");
        if (string.IsNullOrWhiteSpace(unifiedDiff))
            throw new FileMcpException("unified_diff must not be empty");
        RequireContinue(cancellationToken, context, "apply_unified_diff cancelled before compile");

        var source = _versions.ReadExpectedVersioned(relativePath, expectedVersion);
        if (context is not null && !context.TryScanFile(source.SizeBytes))
            throw new FileMcpException("apply_unified_diff budget exhausted while reading source");

        var content = ContentWithoutBom(source.Data);
        ValidateUtf8(content, "apply_unified_diff requires valid UTF-8 source text");
        var sourceLines = BuildLines(content);
        var diff = NormalizeDiffNewlines(unifiedDiff).Split('\n');
        var headerIndex = FindHeader(diff, cancellationToken, context);
        if (headerIndex < 0 || headerIndex + 1 >= diff.Length || !diff[headerIndex + 1].StartsWith("+++ ", StringComparison.Ordinal))
            throw new FileMcpException("apply_unified_diff requires ---/+++ file headers");

        ValidateHeaderPath(diff[headerIndex][4..], relativePath, "old");
        ValidateHeaderPath(diff[headerIndex + 1][4..], relativePath, "new");

        var edits = new List<(int Start, int End, string Replacement, int HunkIndex)>();
        var index = headerIndex + 2;
        var hunkIndex = 0;
        while (index < diff.Length)
        {
            RequireContinue(cancellationToken, context, "apply_unified_diff cancelled during compile");
            if (diff[index].Length == 0)
            {
                index++;
                continue;
            }
            if (diff[index].StartsWith("--- ", StringComparison.Ordinal) || diff[index].StartsWith("+++ ", StringComparison.Ordinal))
                throw new FileMcpException("apply_unified_diff supports exactly one file");
            if (!diff[index].StartsWith("@@ ", StringComparison.Ordinal))
                throw new FileMcpException($"apply_unified_diff malformed unified diff near line {index + 1}");

            var match = HunkHeader.Match(diff[index]);
            if (!match.Success)
                throw new FileMcpException($"apply_unified_diff malformed hunk header: {diff[index]}");
            var oldStart = ParseNonNegative(match.Groups[1].Value, "old start");
            var oldCount = match.Groups[2].Success ? ParseNonNegative(match.Groups[2].Value, "old count") : 1;
            var newStart = ParseNonNegative(match.Groups[3].Value, "new start");
            var newCount = match.Groups[4].Success ? ParseNonNegative(match.Groups[4].Value, "new count") : 1;
            ValidateHunkBounds(oldStart, oldCount, newStart, newCount, sourceLines.Count);

            index++;
            var sourceCursor = oldCount == 0 ? oldStart : oldStart - 1;
            var consumedOld = 0;
            var producedNew = 0;
            var replacementLines = new List<string>();
            char previousPrefix = '\0';
            var newNoNewline = false;
            var sawBody = false;

            while (index < diff.Length && !diff[index].StartsWith("@@ ", StringComparison.Ordinal))
            {
                RequireContinue(cancellationToken, context, "apply_unified_diff cancelled during hunk compile");
                var line = diff[index];
                if (line.StartsWith("--- ", StringComparison.Ordinal) || line.StartsWith("+++ ", StringComparison.Ordinal))
                    throw new FileMcpException("apply_unified_diff supports exactly one file");
                if (line == "\\ No newline at end of file")
                {
                    if (!sawBody)
                        throw new FileMcpException("apply_unified_diff newline marker has no preceding hunk line");
                    if (previousPrefix is '+' or ' ')
                        newNoNewline = true;
                    index++;
                    continue;
                }
                if (line.Length == 0)
                    break;

                var prefix = line[0];
                if (prefix is not (' ' or '+' or '-'))
                    throw new FileMcpException($"apply_unified_diff malformed hunk line near line {index + 1}");
                var text = line[1..];
                sawBody = true;
                previousPrefix = prefix;

                if (prefix is ' ' or '-')
                {
                    if (sourceCursor < 0 || sourceCursor >= sourceLines.Count)
                        throw new FileMcpException("apply_unified_diff hunk extends beyond source file");
                    if (!string.Equals(sourceLines[sourceCursor].Text, text, StringComparison.Ordinal))
                        throw new FileMcpException($"apply_unified_diff hunk context does not match source at line {sourceCursor + 1}");
                    sourceCursor++;
                    consumedOld++;
                }
                if (prefix is ' ' or '+')
                {
                    replacementLines.Add(text);
                    producedNew++;
                }
                if (consumedOld > oldCount || producedNew > newCount)
                    throw new FileMcpException("apply_unified_diff hunk body exceeds declared line counts");
                index++;
            }

            if (!sawBody && (oldCount != 0 || newCount != 0))
                throw new FileMcpException("apply_unified_diff hunk has no body");
            if (consumedOld != oldCount || producedNew != newCount)
                throw new FileMcpException(
                    $"apply_unified_diff hunk line counts do not match header (old {consumedOld}/{oldCount}, new {producedNew}/{newCount})");

            var (startByte, endByte) = HunkByteRange(sourceLines, content.Length, oldStart, oldCount);
            var replacement = replacementLines.Count == 0
                ? ""
                : string.Join("\n", replacementLines) + (newNoNewline ? "" : "\n");
            edits.Add((startByte, endByte, replacement, hunkIndex));
            hunkIndex++;
        }

        if (edits.Count == 0)
            throw new FileMcpException("apply_unified_diff contains no hunks");
        if (edits.Count > 1024)
            throw new FileMcpException("apply_unified_diff supports at most 1024 hunks");

        var ordered = edits.OrderBy(e => e.Start).ThenBy(e => e.End).ThenBy(e => e.HunkIndex).ToList();
        for (var i = 1; i < ordered.Count; i++)
        {
            var previous = ordered[i - 1];
            var current = ordered[i];
            if (current.Start < previous.End || current.Start == previous.Start)
                throw new FileMcpException("apply_unified_diff contains overlapping hunks");
        }

        var json = new JsonArray();
        foreach (var edit in edits)
        {
            json.Add(new JsonObject
            {
                ["start_byte"] = edit.Start,
                ["end_byte"] = edit.End,
                ["replacement"] = edit.Replacement,
            });
        }
        return new EditAdapterCompilation(json, 0, edits.Count);
    }

    private static byte[] ContentWithoutBom(byte[] raw) =>
        raw.Length >= 3 && raw[0] == 0xEF && raw[1] == 0xBB && raw[2] == 0xBF
            ? raw.AsSpan(3).ToArray()
            : raw.ToArray();

    private static void ValidateUtf8(byte[] content, string message)
    {
        try { _ = StrictUtf8.GetString(content); }
        catch (DecoderFallbackException) { throw new FileMcpException(message); }
    }

    private static List<int> FindAll(
        byte[] haystack,
        byte[] needle,
        CancellationToken cancellationToken,
        ToolExecutionContext? context)
    {
        var result = new List<int>();
        if (needle.Length > haystack.Length) return result;
        for (var i = 0; i <= haystack.Length - needle.Length; i++)
        {
            if ((i & 0x3FFF) == 0)
                RequireContinue(cancellationToken, context, "apply_search_replace cancelled during compile");
            if (haystack.AsSpan(i, needle.Length).SequenceEqual(needle))
                result.Add(i);
        }
        return result;
    }

    private static List<SourceLine> BuildLines(byte[] content)
    {
        var result = new List<SourceLine>();
        var start = 0;
        var i = 0;
        while (i < content.Length)
        {
            if (content[i] is not (byte)'\r' and not (byte)'\n')
            {
                i++;
                continue;
            }

            var textEnd = i;
            var end = i + 1;
            if (content[i] == (byte)'\r' && end < content.Length && content[end] == (byte)'\n')
                end++;
            string text;
            try { text = StrictUtf8.GetString(content, start, textEnd - start); }
            catch (DecoderFallbackException) { throw new FileMcpException("apply_unified_diff requires valid UTF-8 source text"); }
            result.Add(new SourceLine(text, start, end, true));
            start = end;
            i = end;
        }
        if (start < content.Length)
        {
            string text;
            try { text = StrictUtf8.GetString(content, start, content.Length - start); }
            catch (DecoderFallbackException) { throw new FileMcpException("apply_unified_diff requires valid UTF-8 source text"); }
            result.Add(new SourceLine(text, start, content.Length, false));
        }
        return result;
    }

    private static int FindHeader(string[] diff, CancellationToken cancellationToken, ToolExecutionContext? context)
    {
        for (var i = 0; i < diff.Length; i++)
        {
            if ((i & 0x3FF) == 0)
                RequireContinue(cancellationToken, context, "apply_unified_diff cancelled before header");
            if (diff[i].StartsWith("--- ", StringComparison.Ordinal)) return i;
        }
        return -1;
    }

    private static void ValidateHeaderPath(string raw, string relativePath, string side)
    {
        var token = raw.Split('\t', 2)[0].Trim();
        if (string.IsNullOrWhiteSpace(token) || token == "/dev/null")
            throw new FileMcpException($"apply_unified_diff {side} path header is unsupported");
        token = token.Replace('\\', '/');
        if (token.StartsWith("a/", StringComparison.Ordinal) || token.StartsWith("b/", StringComparison.Ordinal))
            token = token[2..];
        if (token.StartsWith("/", StringComparison.Ordinal) || Regex.IsMatch(token, @"^[A-Za-z]:/"))
            throw new FileMcpException($"apply_unified_diff {side} path header escapes the workspace");
        var components = token.Split('/', StringSplitOptions.None);
        if (components.Any(component => component is "" or "." or ".."))
            throw new FileMcpException($"apply_unified_diff {side} path header escapes the workspace");

        var expected = relativePath.Replace('\\', '/').TrimStart('/');
        while (expected.StartsWith("./", StringComparison.Ordinal)) expected = expected[2..];
        if (!string.Equals(token, expected, StringComparison.Ordinal))
            throw new FileMcpException($"apply_unified_diff {side} path header does not match relative_path");
    }

    private static int ParseNonNegative(string value, string name)
    {
        if (!int.TryParse(value, out var result) || result < 0)
            throw new FileMcpException($"apply_unified_diff invalid {name}");
        return result;
    }

    private static void ValidateHunkBounds(int oldStart, int oldCount, int newStart, int newCount, int lineCount)
    {
        if (oldCount == 0)
        {
            if (oldStart < 0 || oldStart > lineCount)
                throw new FileMcpException("apply_unified_diff insertion hunk is outside source bounds");
        }
        else
        {
            if (oldStart < 1 || oldStart - 1 > lineCount - oldCount)
                throw new FileMcpException("apply_unified_diff hunk is outside source bounds");
        }
        if (newCount > 0 && newStart < 1)
            throw new FileMcpException("apply_unified_diff new hunk start is invalid");
    }

    private static (int Start, int End) HunkByteRange(
        IReadOnlyList<SourceLine> lines,
        int contentLength,
        int oldStart,
        int oldCount)
    {
        if (oldCount == 0)
        {
            var position = oldStart == 0 ? 0 : lines[oldStart - 1].EndByte;
            return (position, position);
        }
        var first = oldStart - 1;
        var last = checked(first + oldCount - 1);
        return (lines[first].StartByte, lines[last].EndByte);
    }

    private static string NormalizeDiffNewlines(string value) =>
        value.Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n');

    private static void RequireContinue(
        CancellationToken cancellationToken,
        ToolExecutionContext? context,
        string message)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (context is not null && !context.TryContinue())
            throw new OperationCanceledException(message, context.CancellationToken);
    }

    private sealed record SourceLine(string Text, int StartByte, int EndByte, bool HasTerminator);
}
