using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed partial class LocalTools
{
    private readonly SafePathResolver _resolver;
    private readonly string _gitUserName;
    private readonly string _gitUserEmail;
    private readonly bool _enableCommands;
    private readonly string? _safeGitEmptyFile;
    private readonly string? _safeGitHooksDirectory;
    private readonly SemaphoreSlim _toolSlots = new(8, 8);
    private readonly SemaphoreSlim _serializedSlot = new(1, 1);
    private readonly SemaphoreSlim _commandSlots = new(2, 2);
    private readonly SemaphoreSlim _gitSlots = new(3, 3);
    private static readonly HashSet<string> HandlerToolNames = new(StringComparer.Ordinal)
    {
        "list_files", "read_file", "read_file_range", "search_content", "search_filenames",
        "write_file", "delete_file", "delete_directory", "git_init", "git_status", "git_log", "git_diff",
        "git_add", "git_commit", "git_push", "run_command",
    };
    private static readonly HashSet<string> SerializedToolNames = new(StringComparer.Ordinal)
    {
        "write_file", "delete_file", "delete_directory", "run_command",
        "git_init", "git_status", "git_log", "git_diff", "git_add", "git_commit", "git_push",
    };
    private static readonly HashSet<string> SkippedSearchDirectories = new(StringComparer.OrdinalIgnoreCase)
    {
        ".git", ".venv", "node_modules", "__pycache__", "build", "dist",
    };

    public LocalTools(string allowedDirectory, string gitUserName, string gitUserEmail, bool enableCommands)
    {
        _resolver = new SafePathResolver(allowedDirectory);
        _gitUserName = gitUserName;
        _gitUserEmail = gitUserEmail;
        _enableCommands = enableCommands;
        CanonicalToolCatalog.ValidateHandlerCoverage("local_tools", HandlerToolNames);
        if (!enableCommands)
        {
            (_safeGitEmptyFile, _safeGitHooksDirectory) = PrepareSafeGitResources();
        }
    }

    public JsonArray ToolDefinitions => CanonicalToolCatalog.ToolDefinitions("local_tools", commandsEnabled: _enableCommands);

    public bool HasTool(string name) => HandlerToolNames.Contains(name) && (name != "run_command" || _enableCommands);

    public async Task<ToolCallOutput> CallAsync(string name, JsonObject arguments, CancellationToken cancellationToken = default)
    {
        await _toolSlots.WaitAsync(cancellationToken).ConfigureAwait(false);
        var serialize = SerializedToolNames.Contains(name);
        if (serialize)
        {
            await _serializedSlot.WaitAsync(cancellationToken).ConfigureAwait(false);
        }
        try
        {
            ValidateArguments(name, arguments);
            return name switch
            {
                "list_files" => StringArrayOutput(ListFiles(GetString(arguments, "subpath", ""))),
                "read_file" => StringOutput(ReadFile(GetRequiredString(arguments, "relative_path"))),
                "read_file_range" => ObjectOutput(ReadFileRange(
                    GetRequiredString(arguments, "relative_path"),
                    GetRequiredInt(arguments, "start_line"),
                    GetRequiredInt(arguments, "end_line"))),
                "search_content" => ObjectOutput(SearchContent(
                    GetRequiredString(arguments, "query"),
                    GetString(arguments, "path", ""),
                    GetBool(arguments, "case_sensitive", false),
                    GetInt(arguments, "context_lines", 2),
                    GetInt(arguments, "max_results", 20))),
                "search_filenames" => StringArrayOutput(SearchFilenames(GetRequiredString(arguments, "query"))),
                "write_file" => StringOutput(WriteFile(
                    GetRequiredString(arguments, "relative_path"),
                    GetRequiredString(arguments, "content"),
                    GetBool(arguments, "append", false))),
                "delete_file" => StringOutput(DeleteFile(GetRequiredString(arguments, "relative_path"))),
                "delete_directory" => StringOutput(DeleteDirectory(GetRequiredString(arguments, "relative_path"))),
                "run_command" when _enableCommands => StringOutput(await RunCommandAsync(
                    GetRequiredString(arguments, "command"), GetString(arguments, "cwd", ""),
                    GetInt(arguments, "timeout_seconds", ProcessRunner.DefaultCommandTimeoutSeconds), cancellationToken).ConfigureAwait(false)),
                "run_command" => throw new FileMcpException("Command execution is disabled"),
                "git_init" => StringOutput(await GitInitAsync(GetString(arguments, "repo_path", ""), cancellationToken).ConfigureAwait(false)),
                "git_status" => StringOutput(await GitStatusAsync(GetString(arguments, "repo_path", ""), cancellationToken).ConfigureAwait(false)),
                "git_log" => StringOutput(await GitLogAsync(GetString(arguments, "repo_path", ""), GetInt(arguments, "count", 10), cancellationToken).ConfigureAwait(false)),
                "git_diff" => StringOutput(await GitDiffAsync(GetString(arguments, "repo_path", ""), GetString(arguments, "paths", ""), cancellationToken).ConfigureAwait(false)),
                "git_add" => StringOutput(await GitAddAsync(GetString(arguments, "repo_path", ""), GetString(arguments, "paths", "."), cancellationToken).ConfigureAwait(false)),
                "git_commit" => StringOutput(await GitCommitAsync(GetString(arguments, "repo_path", ""), GetString(arguments, "message", "update"), cancellationToken).ConfigureAwait(false)),
                "git_push" => StringOutput(await GitPushAsync(GetString(arguments, "repo_path", ""), cancellationToken).ConfigureAwait(false)),
                _ => throw new FileMcpException($"Unknown tool: {name}"),
            };
        }
        finally
        {
            if (serialize) _serializedSlot.Release();
            _toolSlots.Release();
        }
    }

    private (IReadOnlyList<string> Values, bool Truncated) ListFiles(string subpath)
    {
        var directory = _resolver.Resolve(subpath);
        if (!Directory.Exists(directory)) return ([], false);
        var entries = new DirectoryInfo(directory).EnumerateFileSystemInfos()
            .OrderBy(entry => entry.Name, StringComparer.OrdinalIgnoreCase).ToList();
        return (entries.Take(FileMcpConstants.MaxListEntries)
            .Select(entry => entry.Name + ((entry.Attributes & FileAttributes.Directory) != 0 ? "/" : "")).ToList(),
            entries.Count > FileMcpConstants.MaxListEntries);
    }

    private string ReadFile(string relativePath)
    {
        var target = _resolver.Resolve(relativePath);
        var info = new FileInfo(target);
        if (!info.Exists || (info.Attributes & FileAttributes.Directory) != 0)
            throw new FileMcpException($"No such file: {relativePath}");
        if (info.Length > FileMcpConstants.MaxFileBytes)
            throw new FileMcpException("File is larger than the 5 MB limit for this tool");
        var data = File.ReadAllBytes(target);
        if (data.Length > FileMcpConstants.MaxFileBytes)
            throw new FileMcpException("File is larger than the 5 MB limit for this tool");
        var text = Encoding.UTF8.GetString(data);
        return text.Length > FileMcpConstants.MaxCharsReturned
            ? text[..FileMcpConstants.MaxCharsReturned] + "\n\n[...truncated...]" : text;
    }

    private JsonObject ReadFileRange(string relativePath, int startLine, int endLine)
    {
        if (startLine < 1 || endLine < startLine)
            throw new FileMcpException("start_line and end_line must define a valid 1-based inclusive range");
        var target = _resolver.Resolve(relativePath);
        var info = new FileInfo(target);
        if (!info.Exists || (info.Attributes & FileAttributes.Directory) != 0)
            throw new FileMcpException($"No such file: {relativePath}");
        if (info.Length > FileMcpConstants.MaxFileBytes)
            throw new FileMcpException("File is larger than the 5 MB limit for this tool");
        var data = File.ReadAllBytes(target);
        if (data.Length > FileMcpConstants.MaxFileBytes)
            throw new FileMcpException("File is larger than the 5 MB limit for this tool");
        var lines = SplitTextLines(Encoding.UTF8.GetString(data));
        var totalLines = Math.Max(1, lines.Count);
        if (startLine > totalLines)
            throw new FileMcpException($"start_line {startLine} is beyond the end of the file ({totalLines} lines)");
        var requestedEnd = Math.Min(endLine, totalLines);
        var lineLimitedEnd = Math.Min(requestedEnd, startLine + FileMcpConstants.MaxReadRangeLines - 1);
        var returned = new List<string>();
        var chars = 0;
        for (var lineNumber = startLine; lineNumber <= lineLimitedEnd; lineNumber++)
        {
            var line = lines[lineNumber - 1];
            var separator = returned.Count == 0 ? 0 : 1;
            if (chars + separator + line.Length > FileMcpConstants.MaxReadRangeChars) break;
            returned.Add(line);
            chars += separator + line.Length;
        }
        if (returned.Count == 0)
            throw new FileMcpException($"Line {startLine} is larger than the 80,000 character response limit for read_file_range");
        var actualEnd = startLine + returned.Count - 1;
        return new JsonObject
        {
            ["path"] = relativePath, ["start_line"] = startLine, ["end_line"] = actualEnd,
            ["requested_end_line"] = endLine, ["total_lines"] = totalLines,
            ["has_before"] = startLine > 1, ["has_after"] = actualEnd < totalLines,
            ["truncated"] = actualEnd < requestedEnd, ["content"] = string.Join("\n", returned),
        };
    }

    private JsonObject SearchContent(string query, string path, bool caseSensitive, int contextLines, int maxResults)
    {
        if (string.IsNullOrEmpty(query)) throw new FileMcpException("query must not be empty");
        var searchRoot = _resolver.Resolve(path);
        if (!Directory.Exists(searchRoot)) throw new FileMcpException($"No such search directory: {(string.IsNullOrEmpty(path) ? "." : path)}");
        var context = Math.Clamp(contextLines, 0, 10);
        var max = Math.Clamp(maxResults, 1, FileMcpConstants.MaxSearchContentResults);
        var matches = new JsonArray();
        var visited = 0; var filesScanned = 0; long bytesScanned = 0; var previewChars = 0; var truncated = false;
        var pending = new Stack<string>(); pending.Push(searchRoot);
        while (pending.Count > 0 && !truncated)
        {
            var dir = pending.Pop();
            IEnumerable<FileSystemInfo> entries;
            try { entries = new DirectoryInfo(dir).EnumerateFileSystemInfos().ToList(); } catch { continue; }
            foreach (var entry in entries)
            {
                visited++;
                if (visited > FileMcpConstants.MaxSearchVisited) { truncated = true; break; }
                var isDir = (entry.Attributes & FileAttributes.Directory) != 0;
                if (isDir)
                {
                    if (SkippedSearchDirectories.Contains(entry.Name) || (entry.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    if (_resolver.Contains(entry.FullName)) pending.Push(entry.FullName);
                    continue;
                }
                if (entry is not FileInfo file || file.Length > FileMcpConstants.MaxSearchContentFileBytes) continue;
                if (bytesScanned + file.Length > FileMcpConstants.MaxSearchContentBytesScanned) { truncated = true; break; }
                string safe;
                try { safe = _resolver.Resolve(_resolver.RelativePath(file.FullName)); } catch { continue; }
                byte[] data;
                try { data = File.ReadAllBytes(safe); } catch { continue; }
                if (data.Length > FileMcpConstants.MaxSearchContentFileBytes) continue;
                if (bytesScanned + data.Length > FileMcpConstants.MaxSearchContentBytesScanned) { truncated = true; break; }
                bytesScanned += data.Length;
                if (data.Take(Math.Min(8192, data.Length)).Contains((byte)0)) continue;
                filesScanned++;
                var text = Encoding.UTF8.GetString(data); var lines = SplitTextLines(text);
                for (var index = 0; index < lines.Count; index++)
                {
                    var comparison = caseSensitive ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase;
                    if (!lines[index].Contains(query, comparison)) continue;
                    var lineNumber = index + 1; var previewStart = Math.Max(1, lineNumber - context); var previewEnd = Math.Min(lines.Count, lineNumber + context);
                    var previewLines = new List<string>();
                    for (var number = previewStart; number <= previewEnd; number++)
                    {
                        var value = lines[number - 1];
                        if (value.Length > FileMcpConstants.MaxSearchPreviewLineChars) value = value[..FileMcpConstants.MaxSearchPreviewLineChars] + "...";
                        previewLines.Add($"{number}: {value}");
                    }
                    var preview = string.Join("\n", previewLines);
                    if (previewChars + preview.Length > FileMcpConstants.MaxSearchPreviewChars) { truncated = true; break; }
                    previewChars += preview.Length;
                    matches.Add(new JsonObject { ["path"] = _resolver.RelativePath(file.FullName), ["line"] = lineNumber, ["preview_start_line"] = previewStart, ["preview_end_line"] = previewEnd, ["preview"] = preview });
                    if (matches.Count >= max) { truncated = true; break; }
                }
                if (truncated) break;
            }
        }
        return new JsonObject
        {
            ["query"] = query, ["path"] = path, ["case_sensitive"] = caseSensitive, ["matches"] = matches,
            ["truncated"] = truncated, ["visited_entries"] = Math.Min(visited, FileMcpConstants.MaxSearchVisited),
            ["files_scanned"] = filesScanned, ["bytes_scanned"] = bytesScanned,
        };
    }

    private (IReadOnlyList<string> Values, bool Truncated) SearchFilenames(string query)
    {
        if (string.IsNullOrEmpty(query)) throw new FileMcpException("query must not be empty");
        var matches = new List<string>(); var visited = 0; var truncated = false;
        var pending = new Stack<string>(); pending.Push(_resolver.Root);
        while (pending.Count > 0 && !truncated)
        {
            var dir = pending.Pop();
            IEnumerable<FileSystemInfo> entries;
            try { entries = new DirectoryInfo(dir).EnumerateFileSystemInfos().ToList(); } catch { continue; }
            foreach (var entry in entries)
            {
                visited++; if (visited > FileMcpConstants.MaxSearchVisited) { truncated = true; break; }
                if ((entry.Attributes & FileAttributes.Directory) != 0)
                {
                    if (SkippedSearchDirectories.Contains(entry.Name) || (entry.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    if (_resolver.Contains(entry.FullName)) pending.Push(entry.FullName);
                }
                else if (entry.Name.Contains(query, StringComparison.OrdinalIgnoreCase))
                {
                    var relative = _resolver.RelativePath(entry.FullName);
                    if (!string.IsNullOrEmpty(relative)) matches.Add(relative);
                    if (matches.Count >= FileMcpConstants.MaxSearchResults) { truncated = true; break; }
                }
            }
        }
        return (matches, truncated);
    }

    private string WriteFile(string relativePath, string content, bool append)
    {
        var data = Encoding.UTF8.GetBytes(content);
        if (data.Length > FileMcpConstants.MaxWriteBytes) throw new FileMcpException("Content is larger than the 5 MB write limit");
        var target = _resolver.Resolve(relativePath);
        if (Directory.Exists(target)) throw new FileMcpException($"Not a file: {relativePath}");
        Directory.CreateDirectory(Path.GetDirectoryName(target)!);
        if (append && File.Exists(target))
        {
            using var stream = new FileStream(target, FileMode.Append, FileAccess.Write, FileShare.Read);
            stream.Write(data);
        }
        else
        {
            var temp = target + ".filemcp-" + Guid.NewGuid().ToString("N") + ".tmp";
            try { File.WriteAllBytes(temp, data); File.Move(temp, target, true); }
            finally { try { if (File.Exists(temp)) File.Delete(temp); } catch { } }
        }
        return $"{(append ? "Appended to" : "Wrote")} {relativePath} ({data.Length} bytes)";
    }

    private string DeleteFile(string relativePath)
    {
        var target = _resolver.ResolveForDeletion(relativePath);
        var attributes = _resolver.GetAttributesWithoutFollowingFinalTarget(target, $"No such file: {relativePath}");
        if ((attributes & FileAttributes.Directory) != 0 && (attributes & FileAttributes.ReparsePoint) == 0)
            throw new FileMcpException("delete_file only removes files or symlinks; use delete_directory for folders");
        if ((attributes & FileAttributes.Directory) != 0) Directory.Delete(target, false); else File.Delete(target);
        return $"Deleted {relativePath}";
    }

    private string DeleteDirectory(string relativePath)
    {
        var target = _resolver.ResolveForDeletion(relativePath);
        if (string.Equals(Path.GetFullPath(target).TrimEnd('\\'), Path.GetFullPath(_resolver.Root).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase))
            throw new FileMcpException("Refusing to delete the shared root directory");
        var attributes = _resolver.GetAttributesWithoutFollowingFinalTarget(target, $"No such directory: {relativePath}");
        if ((attributes & FileAttributes.ReparsePoint) != 0 || (attributes & FileAttributes.Directory) == 0)
            throw new FileMcpException($"Not a directory: {relativePath}. Use delete_file for symlinks.");
        Directory.Delete(target, true);
        return $"Deleted directory {relativePath}";
    }

    private async Task<string> RunCommandAsync(string command, string cwd, int timeoutSeconds, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(command)) throw new FileMcpException("command must not be empty");
        var workdir = _resolver.Resolve(cwd);
        if (!Directory.Exists(workdir)) throw new FileMcpException($"No such working directory: {(string.IsNullOrEmpty(cwd) ? "." : cwd)}");
        await _commandSlots.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var result = await ProcessRunner.RunAsync(PowerShellPath(), ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", command], workdir,
                Environment.GetEnvironmentVariables().Cast<System.Collections.DictionaryEntry>().ToDictionary(e => (string)e.Key, e => (string?)e.Value ?? "", StringComparer.OrdinalIgnoreCase),
                timeoutSeconds, FileMcpConstants.MaxToolProcessOutputBytes, cancellationToken).ConfigureAwait(false);
            if (result.TimedOut)
            {
                var partial = $"Command timed out after {Math.Clamp(timeoutSeconds, 1, ProcessRunner.MaxCommandTimeoutSeconds)} seconds.";
                if (!string.IsNullOrEmpty(result.Stdout)) partial += "\nstdout:\n" + result.Stdout;
                if (!string.IsNullOrEmpty(result.Stderr)) partial += "\nstderr:\n" + result.Stderr;
                throw new FileMcpException(partial);
            }
            return FormatProcessResult(result);
        }
        finally { _commandSlots.Release(); }
    }

    private static string PowerShellPath()
    {
        var system = Environment.GetFolderPath(Environment.SpecialFolder.System);
        var candidate = Path.Combine(system, "WindowsPowerShell", "v1.0", "powershell.exe");
        return File.Exists(candidate) ? candidate : "powershell.exe";
    }

    private static List<string> SplitTextLines(string text)
    {
        var normalized = text.Replace("\r\n", "\n").Replace('\r', '\n');
        var lines = normalized.Split('\n', StringSplitOptions.None).ToList();
        if (normalized.EndsWith('\n') && lines.Count > 1) lines.RemoveAt(lines.Count - 1);
        return lines.Count == 0 ? [""] : lines;
    }

    private static ToolCallOutput StringOutput(string value) => new(
        new JsonArray(new JsonObject { ["type"] = "text", ["text"] = value }), new JsonObject { ["result"] = value });

    private static ToolCallOutput StringArrayOutput((IReadOnlyList<string> Values, bool Truncated) value)
    {
        var content = new JsonArray(); var result = new JsonArray();
        foreach (var item in value.Values) { content.Add(new JsonObject { ["type"] = "text", ["text"] = item }); result.Add(item); }
        return new ToolCallOutput(content, new JsonObject { ["result"] = result, ["truncated"] = value.Truncated });
    }

    private static ToolCallOutput ObjectOutput(JsonObject value) => new(
        new JsonArray(new JsonObject { ["type"] = "text", ["text"] = value.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) }), value);

    private static string GetRequiredString(JsonObject args, string key) => args[key] is JsonValue value && value.TryGetValue<string>(out var result) ? result : throw new FileMcpException($"Missing or invalid argument: {key}");
    private static int GetRequiredInt(JsonObject args, string key) => args[key] is JsonValue value && value.TryGetValue<int>(out var result) ? result : throw new FileMcpException($"Missing or invalid argument: {key}");
    private static string GetString(JsonObject args, string key, string fallback) => args[key] is JsonValue value && value.TryGetValue<string>(out var result) ? result : fallback;
    private static bool GetBool(JsonObject args, string key, bool fallback) => args[key] is JsonValue value && value.TryGetValue<bool>(out var result) ? result : fallback;
    private static int GetInt(JsonObject args, string key, int fallback) => args[key] is JsonValue value && value.TryGetValue<int>(out var result) ? result : fallback;

    private void ValidateArguments(string toolName, JsonObject arguments)
    {
        var definition = ToolDefinitions.OfType<JsonObject>().FirstOrDefault(tool => tool["name"]?.GetValue<string>() == toolName)
            ?? throw new FileMcpException($"Invalid tool definition: {toolName}");
        var schema = definition["inputSchema"]!.AsObject(); var properties = schema["properties"]!.AsObject();
        var required = schema["required"]!.AsArray().Select(node => node!.GetValue<string>()).ToHashSet(StringComparer.Ordinal);
        foreach (var pair in arguments)
        {
            if (!properties.ContainsKey(pair.Key)) throw new FileMcpException($"Unexpected argument: {pair.Key}");
        }
        foreach (var key in required)
        {
            if (!arguments.ContainsKey(key) || arguments[key] is null) throw new FileMcpException($"Missing or invalid argument: {key}");
        }
        foreach (var pair in arguments)
        {
            var property = properties[pair.Key]!.AsObject(); var type = property["type"]!.GetValue<string>(); var valid = pair.Value is JsonValue v && type switch
            {
                "string" => v.TryGetValue<string>(out _), "boolean" => v.TryGetValue<bool>(out _), "integer" => v.TryGetValue<int>(out _), _ => true,
            };
            if (!valid) throw new FileMcpException($"Missing or invalid argument: {pair.Key}");
            if (type == "integer")
            {
                var number = pair.Value!.GetValue<int>();
                if (property["minimum"] is JsonValue min && number < min.GetValue<int>()) throw new FileMcpException($"Argument {pair.Key} must be >= {min.GetValue<int>()}");
                if (property["maximum"] is JsonValue max && number > max.GetValue<int>()) throw new FileMcpException($"Argument {pair.Key} must be <= {max.GetValue<int>()}");
            }
        }
    }

    private static string FormatProcessResult(ProcessResult result)
    {
        var sections = new List<string> { $"exit_code: {result.ExitCode}" };
        var stdout = result.Stdout.TrimEnd('\r', '\n'); var stderr = result.Stderr.TrimEnd('\r', '\n');
        if (stdout.Length > 0) sections.Add("stdout:\n" + stdout); if (stderr.Length > 0) sections.Add("stderr:\n" + stderr);
        if (stdout.Length == 0 && stderr.Length == 0) sections.Add("(no output)");
        return string.Join("\n\n", sections);
    }
}
