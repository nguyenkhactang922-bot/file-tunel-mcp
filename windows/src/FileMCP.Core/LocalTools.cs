using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed partial class LocalTools
{
    private readonly SafePathResolver _resolver;
    private readonly string _gitUserName;
    private readonly string _gitUserEmail;
    private readonly ServerPolicy _policy;
    private readonly ExecProcessEnvironmentAuthority _execEnvironment;
    private readonly FileVersionService _fileVersions;
    private readonly AuthorizedPathSnapshotService _mutationGuard;
    private readonly ProjectContextService _projectContext;
    private readonly Action<string>? _beforeMutationCommitForTests;
    private readonly Action<string>? _applyEditsStageForTests;
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
        "write_file", "delete_file", "delete_directory", "apply_edits", "project_context", "git_init", "git_status", "git_log", "git_diff",
        "git_add", "git_commit", "git_push", "exec_process", "run_command",
    };
    private static readonly HashSet<string> SerializedToolNames = new(StringComparer.Ordinal)
    {
        "write_file", "delete_file", "delete_directory", "apply_edits", "run_command",
        "git_init", "git_status", "git_log", "git_diff", "git_add", "git_commit", "git_push",
    };
    private static readonly HashSet<string> BudgetedToolNames = new(StringComparer.Ordinal)
    {
        "list_files", "search_content", "search_filenames", "write_file", "delete_file", "delete_directory", "apply_edits", "project_context", "exec_process",
    };
    private static readonly HashSet<string> SkippedSearchDirectories = new(StringComparer.OrdinalIgnoreCase)
    {
        ".git", ".venv", "node_modules", "__pycache__", "build", "dist",
    };

    public LocalTools(string allowedDirectory, string gitUserName, string gitUserEmail, bool enableCommands)
        : this(allowedDirectory, gitUserName, gitUserEmail, ServerPolicy.FromLegacy(enableCommands), null)
    {
    }

    internal LocalTools(
        string allowedDirectory,
        string gitUserName,
        string gitUserEmail,
        ServerPolicy policy,
        IReadOnlyList<string>? execEnvironmentAllowList = null,
        Action<string>? beforeMutationCommitForTests = null,
        Action<string>? applyEditsStageForTests = null,
        CodexSkillRegistry? skillRegistry = null)
    {
        _resolver = new SafePathResolver(allowedDirectory);
        _fileVersions = new FileVersionService(_resolver);
        _mutationGuard = new AuthorizedPathSnapshotService(_resolver);
        _projectContext = new ProjectContextService(_resolver, policy, skillRegistry);
        _beforeMutationCommitForTests = beforeMutationCommitForTests;
        _applyEditsStageForTests = applyEditsStageForTests;
        _gitUserName = gitUserName;
        _gitUserEmail = gitUserEmail;
        _policy = policy;
        _execEnvironment = new ExecProcessEnvironmentAuthority(execEnvironmentAllowList);
        _enableCommands = _policy.LegacyUnsafeGitCompatibility;
        CanonicalToolCatalog.ValidateHandlerCoverage("local_tools", HandlerToolNames);
        if (!_enableCommands)
        {
            (_safeGitEmptyFile, _safeGitHooksDirectory) = PrepareSafeGitResources();
        }
    }

    public JsonArray ToolDefinitions => _policy.FilterDefinitions(CanonicalToolCatalog.ToolDefinitions("local_tools", commandsEnabled: true));

    public bool HasTool(string name) => HandlerToolNames.Contains(name) && _policy.IsAllowed(name);
    internal bool SupportsBudget(string name) => BudgetedToolNames.Contains(name);

    public async Task<ToolCallOutput> CallAsync(string name, JsonObject arguments, CancellationToken cancellationToken = default, ToolExecutionContext? executionContext = null)
    {
        var effectiveCancellation = executionContext?.CancellationToken ?? cancellationToken;
        await _toolSlots.WaitAsync(effectiveCancellation).ConfigureAwait(false);
        var serialize = SerializedToolNames.Contains(name);
        if (serialize)
        {
            await _serializedSlot.WaitAsync(effectiveCancellation).ConfigureAwait(false);
        }
        try
        {
            if (!HandlerToolNames.Contains(name)) throw new FileMcpException($"Unknown tool: {name}");
            var preparedPolicy = _policy.Capture();
            _policy.Authorize(name, preparedPolicy);
            ValidateArguments(name, arguments);
            _policy.Authorize(name, preparedPolicy);
            return name switch
            {
                "list_files" => StringArrayOutput(ListFiles(GetString(arguments, "subpath", ""), executionContext)),
                "read_file" => VersionedStringOutput(ReadFile(GetRequiredString(arguments, "relative_path"))),
                "read_file_range" => ObjectOutput(ReadFileRange(
                    GetRequiredString(arguments, "relative_path"),
                    GetRequiredInt(arguments, "start_line"),
                    GetRequiredInt(arguments, "end_line"))),
                "search_content" => ObjectOutput(SearchContent(
                    GetRequiredString(arguments, "query"),
                    GetString(arguments, "path", ""),
                    GetBool(arguments, "case_sensitive", false),
                    GetInt(arguments, "context_lines", 2),
                    GetInt(arguments, "max_results", 20),
                    executionContext)),
                "search_filenames" => StringArrayOutput(SearchFilenames(GetRequiredString(arguments, "query"), executionContext)),
                "write_file" => StringOutput(WriteFile(
                    GetRequiredString(arguments, "relative_path"),
                    GetRequiredString(arguments, "content"),
                    GetBool(arguments, "append", false),
                    GetString(arguments, "expected_version", ""),
                    preparedPolicy,
                    effectiveCancellation)),
                "delete_file" => StringOutput(DeleteFile(
                    GetRequiredString(arguments, "relative_path"),
                    GetString(arguments, "expected_version", ""),
                    GetBool(arguments, "dry_run", false),
                    preparedPolicy,
                    effectiveCancellation)),
                "delete_directory" => StringOutput(DeleteDirectory(
                    GetRequiredString(arguments, "relative_path"),
                    GetBool(arguments, "dry_run", false),
                    preparedPolicy,
                    effectiveCancellation)),
                "apply_edits" => ObjectOutput(ApplyEdits(
                    GetRequiredString(arguments, "relative_path"),
                    GetRequiredString(arguments, "expected_version"),
                    GetRequiredString(arguments, "coordinate_system"),
                    GetString(arguments, "column_encoding", ""),
                    GetRequiredArray(arguments, "edits"),
                    GetBool(arguments, "dry_run", false),
                    GetBool(arguments, "preserve_line_endings", true),
                    GetBool(arguments, "preserve_bom", true),
                    preparedPolicy,
                    effectiveCancellation,
                    executionContext)),
                "project_context" => ObjectOutput(_projectContext.Capture(
                    GetString(arguments, "path", ""),
                    GetString(arguments, "cursor", ""),
                    GetInt(arguments, "max_lines", ProjectContextService.DefaultMaxLines),
                    GetBool(arguments, "include_skills", true),
                    executionContext)),
                "exec_process" => ObjectOutput(await ExecProcessAsync(
                    GetRequiredString(arguments, "executable"),
                    GetStringArray(arguments, "arguments"),
                    GetString(arguments, "cwd", ""),
                    GetStringDictionary(arguments, "environment"),
                    GetInt(arguments, "timeout_seconds", ProcessRunner.DefaultCommandTimeoutSeconds),
                    GetInt(arguments, "output_limit_bytes", FileMcpConstants.MaxToolProcessOutputBytes),
                    preparedPolicy,
                    effectiveCancellation).ConfigureAwait(false)),
                "run_command" => StringOutput(await RunCommandAsync(
                    GetRequiredString(arguments, "command"), GetString(arguments, "cwd", ""),
                    GetInt(arguments, "timeout_seconds", ProcessRunner.DefaultCommandTimeoutSeconds), cancellationToken).ConfigureAwait(false)),
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

    private (IReadOnlyList<string> Values, bool Truncated) ListFiles(string subpath, ToolExecutionContext? context)
    {
        var directory = _resolver.Resolve(subpath);
        if (!Directory.Exists(directory)) return ([], false);

        var collected = new List<FileSystemInfo>();
        var truncated = false;
        try
        {
            foreach (var entry in new DirectoryInfo(directory).EnumerateFileSystemInfos())
            {
                if (context is not null && !context.TryVisitEntry())
                {
                    truncated = true;
                    break;
                }
                collected.Add(entry);
            }
        }
        catch (OperationCanceledException)
        {
            context?.MarkTruncated("cancelled");
            truncated = true;
        }

        var entries = collected.OrderBy(entry => entry.Name, StringComparer.OrdinalIgnoreCase);
        var result = new List<string>();
        foreach (var entry in entries)
        {
            if (result.Count >= FileMcpConstants.MaxListEntries)
            {
                context?.MarkTruncated("server_limit");
                truncated = true;
                break;
            }
            if (context is not null && !context.TryOutputItem())
            {
                truncated = true;
                break;
            }
            result.Add(entry.Name + ((entry.Attributes & FileAttributes.Directory) != 0 ? "/" : ""));
        }
        return (result, truncated || (context?.Truncated ?? false));
    }

    private JsonObject ReadFile(string relativePath)
    {
        var versioned = _fileVersions.ReadVersioned(relativePath, FileMcpConstants.MaxFileBytes);
        var text = Encoding.UTF8.GetString(versioned.Data);
        var result = text.Length > FileMcpConstants.MaxCharsReturned
            ? text[..FileMcpConstants.MaxCharsReturned] + "\n\n[...truncated...]" : text;
        return new JsonObject
        {
            ["result"] = result,
            ["version"] = versioned.VersionToken,
            ["version_strength"] = "content",
            ["size_bytes"] = versioned.SizeBytes,
        };
    }

    private JsonObject ReadFileRange(string relativePath, int startLine, int endLine)
    {
        if (startLine < 1 || endLine < startLine)
            throw new FileMcpException("start_line and end_line must define a valid 1-based inclusive range");
        var versioned = _fileVersions.ReadVersioned(relativePath, FileMcpConstants.MaxFileBytes);
        var lines = SplitTextLines(Encoding.UTF8.GetString(versioned.Data));
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
            ["version"] = versioned.VersionToken, ["version_strength"] = "content", ["size_bytes"] = versioned.SizeBytes,
        };
    }

    private JsonObject SearchContent(
        string query,
        string path,
        bool caseSensitive,
        int contextLines,
        int maxResults,
        ToolExecutionContext? context)
    {
        if (string.IsNullOrEmpty(query)) throw new FileMcpException("query must not be empty");
        var searchRoot = _resolver.Resolve(path);
        if (!Directory.Exists(searchRoot)) throw new FileMcpException($"No such search directory: {(string.IsNullOrEmpty(path) ? "." : path)}");
        var contextLinesEffective = Math.Clamp(contextLines, 0, 10);
        var hardMax = Math.Clamp(maxResults, 1, FileMcpConstants.MaxSearchContentResults);
        var max = context is null ? hardMax : Math.Min(hardMax, context.Limits.MaxOutputItems);

        var matches = new JsonArray();
        var visited = 0;
        var filesScanned = 0;
        long bytesScanned = 0;
        var previewChars = 0;
        var truncated = false;
        var pending = new Stack<string>();
        pending.Push(searchRoot);

        while (pending.Count > 0 && !truncated)
        {
            if (context is not null && !context.TryContinue())
            {
                truncated = true;
                break;
            }

            var dir = pending.Pop();
            IEnumerable<FileSystemInfo> entries;
            try { entries = new DirectoryInfo(dir).EnumerateFileSystemInfos(); }
            catch { continue; }

            try
            {
                foreach (var entry in entries)
                {
                    if (context is not null)
                    {
                        if (!context.TryVisitEntry()) { truncated = true; break; }
                    }
                    visited++;
                    if (context is null && visited > FileMcpConstants.MaxSearchVisited) { truncated = true; break; }

                    var isDir = (entry.Attributes & FileAttributes.Directory) != 0;
                    if (isDir)
                    {
                        if (SkippedSearchDirectories.Contains(entry.Name) || (entry.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                        if (_resolver.Contains(entry.FullName)) pending.Push(entry.FullName);
                        continue;
                    }

                    if (entry is not FileInfo file || file.Length > FileMcpConstants.MaxSearchContentFileBytes) continue;
                    if (bytesScanned + file.Length > FileMcpConstants.MaxSearchContentBytesScanned)
                    {
                        context?.MarkTruncated("bytes_scanned");
                        truncated = true;
                        break;
                    }
                    if (context is not null && (context.RemainingFiles <= 0 || file.Length > context.RemainingBytes))
                    {
                        context.MarkTruncated(context.RemainingFiles <= 0 ? "files_scanned" : "bytes_scanned");
                        truncated = true;
                        break;
                    }

                    string safe;
                    try { safe = _resolver.Resolve(_resolver.RelativePath(file.FullName)); } catch { continue; }
                    byte[] data;
                    try
                    {
                        var readLimit = context is null
                            ? FileMcpConstants.MaxSearchContentFileBytes
                            : (int)Math.Min(FileMcpConstants.MaxSearchContentFileBytes, context.RemainingBytes);
                        var bounded = ReadFileAtMost(safe, readLimit);
                        if (bounded.Exceeded)
                        {
                            context?.MarkTruncated("bytes_scanned");
                            truncated = true;
                            break;
                        }
                        data = bounded.Data;
                    }
                    catch { continue; }
                    if (data.Length > FileMcpConstants.MaxSearchContentFileBytes) continue;
                    if (bytesScanned + data.Length > FileMcpConstants.MaxSearchContentBytesScanned)
                    {
                        context?.MarkTruncated("bytes_scanned");
                        truncated = true;
                        break;
                    }
                    if (context is not null && !context.TryScanFile(data.Length))
                    {
                        truncated = true;
                        break;
                    }

                    bytesScanned += data.Length;
                    if (data.Take(Math.Min(8192, data.Length)).Contains((byte)0)) continue;
                    filesScanned++;

                    var text = Encoding.UTF8.GetString(data);
                    var lines = SplitTextLines(text);
                    for (var index = 0; index < lines.Count; index++)
                    {
                        if (context is not null && !context.TryContinue())
                        {
                            truncated = true;
                            break;
                        }

                        var comparison = caseSensitive ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase;
                        if (!lines[index].Contains(query, comparison)) continue;

                        var lineNumber = index + 1;
                        var previewStart = Math.Max(1, lineNumber - contextLinesEffective);
                        var previewEnd = Math.Min(lines.Count, lineNumber + contextLinesEffective);
                        var previewLines = new List<string>();
                        for (var number = previewStart; number <= previewEnd; number++)
                        {
                            var value = lines[number - 1];
                            if (value.Length > FileMcpConstants.MaxSearchPreviewLineChars)
                                value = value[..FileMcpConstants.MaxSearchPreviewLineChars] + "...";
                            previewLines.Add($"{number}: {value}");
                        }

                        var preview = string.Join("\n", previewLines);
                        if (previewChars + preview.Length > FileMcpConstants.MaxSearchPreviewChars)
                        {
                            context?.MarkTruncated("server_limit");
                            truncated = true;
                            break;
                        }
                        if (context is not null && !context.TryOutputItem())
                        {
                            truncated = true;
                            break;
                        }

                        previewChars += preview.Length;
                        matches.Add(new JsonObject
                        {
                            ["path"] = _resolver.RelativePath(file.FullName),
                            ["line"] = lineNumber,
                            ["preview_start_line"] = previewStart,
                            ["preview_end_line"] = previewEnd,
                            ["preview"] = preview,
                        });

                        if (matches.Count >= max)
                        {
                            context?.MarkTruncated(context.Limits.MaxOutputItems < hardMax ? "output_items" : "server_limit");
                            truncated = true;
                            break;
                        }
                    }
                    if (truncated) break;
                }
            }
            catch (OperationCanceledException)
            {
                context?.MarkTruncated("cancelled");
                truncated = true;
            }
        }

        return new JsonObject
        {
            ["query"] = query,
            ["path"] = path,
            ["case_sensitive"] = caseSensitive,
            ["matches"] = matches,
            ["truncated"] = truncated || (context?.Truncated ?? false),
            ["visited_entries"] = Math.Min(visited, FileMcpConstants.MaxSearchVisited),
            ["files_scanned"] = filesScanned,
            ["bytes_scanned"] = bytesScanned,
        };
    }

    private static (byte[] Data, bool Exceeded) ReadFileAtMost(string path, int maxBytes)
    {
        if (maxBytes < 0) return ([], true);
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        using var output = new MemoryStream(Math.Min(maxBytes, 64 * 1024));
        var buffer = new byte[Math.Min(64 * 1024, Math.Max(1, maxBytes + 1))];
        var remainingPlusSentinel = (long)maxBytes + 1;
        while (remainingPlusSentinel > 0)
        {
            var requested = (int)Math.Min(buffer.Length, remainingPlusSentinel);
            var read = stream.Read(buffer, 0, requested);
            if (read == 0) break;
            output.Write(buffer, 0, read);
            remainingPlusSentinel -= read;
            if (output.Length > maxBytes) return ([], true);
        }
        return (output.ToArray(), false);
    }

    private (IReadOnlyList<string> Values, bool Truncated) SearchFilenames(string query, ToolExecutionContext? context)
    {
        if (string.IsNullOrEmpty(query)) throw new FileMcpException("query must not be empty");

        var matches = new List<string>();
        var visited = 0;
        var truncated = false;
        var pending = new Stack<string>();
        pending.Push(_resolver.Root);

        while (pending.Count > 0 && !truncated)
        {
            if (context is not null && !context.TryContinue())
            {
                truncated = true;
                break;
            }

            var dir = pending.Pop();
            IEnumerable<FileSystemInfo> entries;
            try { entries = new DirectoryInfo(dir).EnumerateFileSystemInfos(); }
            catch { continue; }

            try
            {
                foreach (var entry in entries)
                {
                    if (context is not null)
                    {
                        if (!context.TryVisitEntry()) { truncated = true; break; }
                    }
                    visited++;
                    if (context is null && visited > FileMcpConstants.MaxSearchVisited) { truncated = true; break; }

                    if ((entry.Attributes & FileAttributes.Directory) != 0)
                    {
                        if (SkippedSearchDirectories.Contains(entry.Name) || (entry.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                        if (_resolver.Contains(entry.FullName)) pending.Push(entry.FullName);
                    }
                    else if (entry.Name.Contains(query, StringComparison.OrdinalIgnoreCase))
                    {
                        var relative = _resolver.RelativePath(entry.FullName);
                        if (string.IsNullOrEmpty(relative)) continue;

                        if (matches.Count >= FileMcpConstants.MaxSearchResults)
                        {
                            context?.MarkTruncated("server_limit");
                            truncated = true;
                            break;
                        }
                        if (context is not null && !context.TryOutputItem())
                        {
                            truncated = true;
                            break;
                        }

                        matches.Add(relative);
                        if (matches.Count >= FileMcpConstants.MaxSearchResults)
                        {
                            context?.MarkTruncated("server_limit");
                            truncated = true;
                            break;
                        }
                    }
                }
            }
            catch (OperationCanceledException)
            {
                context?.MarkTruncated("cancelled");
                truncated = true;
            }
        }

        return (matches, truncated || (context?.Truncated ?? false));
    }

    private string WriteFile(
        string relativePath,
        string content,
        bool append,
        string expectedVersion,
        PolicySnapshot preparedPolicy,
        CancellationToken cancellationToken)
    {
        var data = Encoding.UTF8.GetBytes(content);
        if (data.Length > FileMcpConstants.MaxWriteBytes) throw new FileMcpException("Content is larger than the 5 MB write limit");
        cancellationToken.ThrowIfCancellationRequested();
        var target = _resolver.Resolve(relativePath);
        if (Directory.Exists(target)) throw new FileMcpException($"Not a file: {relativePath}");

        var existed = File.Exists(target);
        var normalizedExpected = NormalizeExpectedVersion(expectedVersion);
        if (normalizedExpected is not null)
        {
            if (!existed) throw new FileMcpException("expected_version requires an existing file target");
            _ = _fileVersions.VerifyExpectedVersion(relativePath, normalizedExpected);
        }

        Directory.CreateDirectory(Path.GetDirectoryName(target)!);
        var snapshot = existed
            ? _mutationGuard.CaptureExisting(relativePath)
            : _mutationGuard.CaptureNewTarget(relativePath);
        var temp = target + ".filemcp-" + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            if (append && existed)
            {
                File.Copy(target, temp, overwrite: false);
                using var stream = new FileStream(temp, FileMode.Append, FileAccess.Write, FileShare.None);
                stream.Write(data);
            }
            else
            {
                File.WriteAllBytes(temp, data);
            }

            PrepareMutationCommit("write_file", preparedPolicy, cancellationToken);
            _ = _mutationGuard.Verify(snapshot);
            if (normalizedExpected is not null)
                _ = _fileVersions.VerifyExpectedVersion(relativePath, normalizedExpected);
            cancellationToken.ThrowIfCancellationRequested();
            File.Move(temp, target, true);
        }
        finally
        {
            try { if (File.Exists(temp)) File.Delete(temp); } catch { }
        }
        return $"{(append ? "Appended to" : "Wrote")} {relativePath} ({data.Length} bytes)";
    }

    private string DeleteFile(
        string relativePath,
        string expectedVersion,
        bool dryRun,
        PolicySnapshot preparedPolicy,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var target = _resolver.ResolveForDeletion(relativePath);
        var attributes = _resolver.GetAttributesWithoutFollowingFinalTarget(target, $"No such file: {relativePath}");
        if ((attributes & FileAttributes.Directory) != 0 && (attributes & FileAttributes.ReparsePoint) == 0)
            throw new FileMcpException("delete_file only removes files or symlinks; use delete_directory for folders");

        var normalizedExpected = NormalizeExpectedVersion(expectedVersion);
        if (normalizedExpected is not null)
        {
            if ((attributes & FileAttributes.ReparsePoint) != 0)
                throw new FileMcpException("expected_version is only supported for regular file targets");
            _ = _fileVersions.VerifyExpectedVersion(relativePath, normalizedExpected);
        }
        var snapshot = _mutationGuard.CaptureExisting(relativePath);
        if (dryRun)
        {
            _ = _mutationGuard.Verify(snapshot);
            if (normalizedExpected is not null)
                _ = _fileVersions.VerifyExpectedVersion(relativePath, normalizedExpected);
            return $"Dry run: would delete {relativePath}";
        }

        PrepareMutationCommit("delete_file", preparedPolicy, cancellationToken);
        _ = _mutationGuard.Verify(snapshot);
        if (normalizedExpected is not null)
            _ = _fileVersions.VerifyExpectedVersion(relativePath, normalizedExpected);
        cancellationToken.ThrowIfCancellationRequested();
        if ((attributes & FileAttributes.Directory) != 0) Directory.Delete(target, false); else File.Delete(target);
        return $"Deleted {relativePath}";
    }

    private string DeleteDirectory(
        string relativePath,
        bool dryRun,
        PolicySnapshot preparedPolicy,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var target = _resolver.ResolveForDeletion(relativePath);
        if (string.Equals(Path.GetFullPath(target).TrimEnd('\\'), Path.GetFullPath(_resolver.Root).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase))
            throw new FileMcpException("Refusing to delete the shared root directory");
        var attributes = _resolver.GetAttributesWithoutFollowingFinalTarget(target, $"No such directory: {relativePath}");
        if ((attributes & FileAttributes.ReparsePoint) != 0 || (attributes & FileAttributes.Directory) == 0)
            throw new FileMcpException($"Not a directory: {relativePath}. Use delete_file for symlinks.");

        var snapshot = _mutationGuard.CaptureExisting(relativePath);
        if (dryRun)
        {
            _ = _mutationGuard.Verify(snapshot);
            return $"Dry run: would delete directory {relativePath}";
        }

        PrepareMutationCommit("delete_directory", preparedPolicy, cancellationToken);
        _ = _mutationGuard.Verify(snapshot);
        cancellationToken.ThrowIfCancellationRequested();
        Directory.Delete(target, true);
        return $"Deleted directory {relativePath}";
    }

    private void PrepareMutationCommit(string toolName, PolicySnapshot preparedPolicy, CancellationToken cancellationToken)
    {
        _beforeMutationCommitForTests?.Invoke(toolName);
        cancellationToken.ThrowIfCancellationRequested();
        _policy.Authorize(toolName, preparedPolicy);
    }

    private static string? NormalizeExpectedVersion(string value)
    {
        var normalized = (value ?? "").Trim();
        return normalized.Length == 0 ? null : normalized;
    }

    private JsonObject ApplyEdits(
        string relativePath,
        string expectedVersion,
        string coordinateSystem,
        string columnEncoding,
        JsonArray edits,
        bool dryRun,
        bool preserveLineEndings,
        bool preserveBom,
        PolicySnapshot preparedPolicy,
        CancellationToken cancellationToken,
        ToolExecutionContext? executionContext)
    {
        if (string.IsNullOrWhiteSpace(expectedVersion)) throw new FileMcpException("expected_version must not be empty");
        if (edits.Count is < 1 or > 1024) throw new FileMcpException("apply_edits supports 1..1024 edits");
        if (coordinateSystem is not ("byte" or "lineColumn")) throw new FileMcpException("coordinate_system must be byte or lineColumn");
        if (coordinateSystem == "lineColumn" && columnEncoding != "utf8CodePoint")
            throw new FileMcpException("lineColumn coordinates require column_encoding=utf8CodePoint");
        if (coordinateSystem == "byte" && !string.IsNullOrEmpty(columnEncoding))
            throw new FileMcpException("column_encoding is only valid with lineColumn coordinates");
        cancellationToken.ThrowIfCancellationRequested();
        if (executionContext is not null && !executionContext.TryContinue()) throw new OperationCanceledException("apply_edits cancelled before read", cancellationToken);

        var versioned = _fileVersions.ReadExpectedVersioned(relativePath, expectedVersion);
        _applyEditsStageForTests?.Invoke("after_read");
        cancellationToken.ThrowIfCancellationRequested();
        if (executionContext is not null && !executionContext.TryScanFile(versioned.SizeBytes))
            throw new FileMcpException("apply_edits budget exhausted while reading source");

        var raw = versioned.Data;
        var hasBom = raw.Length >= 3 && raw[0] == 0xEF && raw[1] == 0xBB && raw[2] == 0xBF;
        var content = hasBom ? raw.AsSpan(3).ToArray() : raw.ToArray();
        string text;
        try
        {
            text = new UTF8Encoding(false, true).GetString(content);
        }
        catch (DecoderFallbackException)
        {
            throw new FileMcpException("apply_edits requires valid UTF-8 source text");
        }

        var newline = DetectPreferredNewline(text);
        var compiled = CompileEdits(edits, coordinateSystem, text, content, preserveLineEndings ? newline : null);
        var replacementBytes = compiled.Sum(edit => (long)edit.Replacement.Length);
        var removedBytes = compiled.Sum(edit => (long)(edit.EndByte - edit.StartByte));
        var outputContentBytes = checked(content.LongLength - removedBytes + replacementBytes);
        var outputSize = checked(outputContentBytes + (preserveBom && hasBom ? 3 : 0));
        if (outputSize > FileMcpConstants.MaxWriteBytes) throw new FileMcpException("apply_edits result is larger than the 5 MB write limit");
        if (executionContext is not null && replacementBytes > executionContext.RemainingBytes)
            throw new FileMcpException("apply_edits budget exhausted by replacement content");

        var previewBytes = ApplyCompiledEdits(content, compiled, preserveBom && hasBom);
        var snapshot = _mutationGuard.CaptureExisting(relativePath);
        var result = new JsonObject
        {
            ["dry_run"] = dryRun,
            ["committed"] = false,
            ["edits_applied"] = compiled.Count,
            ["bytes_before"] = raw.LongLength,
            ["bytes_after"] = previewBytes.LongLength,
            ["coordinate_system"] = coordinateSystem,
            ["column_encoding"] = coordinateSystem == "lineColumn" ? "utf8CodePoint" : null,
            ["before_version"] = versioned.VersionToken,
            ["preserved_bom"] = preserveBom && hasBom,
            ["line_ending"] = newline == "\r\n" ? "crlf" : newline == "\r" ? "cr" : "lf",
        };

        if (dryRun)
        {
            _policy.Authorize("apply_edits", preparedPolicy);
            _ = _mutationGuard.Verify(snapshot);
            _ = _fileVersions.VerifyExpectedVersion(relativePath, expectedVersion);
            result["preview"] = PreviewUtf8(previewBytes, 8192);
            result["after_version"] = null;
            return result;
        }

        var target = _resolver.Resolve(relativePath);
        var temp = target + ".filemcp-edits-" + Guid.NewGuid().ToString("N") + ".tmp";
        var committed = false;
        try
        {
            using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                stream.Write(previewBytes);
                stream.Flush(flushToDisk: true);
            }
            _applyEditsStageForTests?.Invoke("after_stage");
            cancellationToken.ThrowIfCancellationRequested();
            if (executionContext is not null && !executionContext.TryContinue()) throw new OperationCanceledException("apply_edits cancelled before commit", cancellationToken);

            _applyEditsStageForTests?.Invoke("before_commit");
            cancellationToken.ThrowIfCancellationRequested();
            if (executionContext is not null && !executionContext.TryContinue()) throw new OperationCanceledException("apply_edits cancelled before commit", cancellationToken);
            _policy.Authorize("apply_edits", preparedPolicy);
            _ = _mutationGuard.Verify(snapshot);
            _ = _fileVersions.VerifyExpectedVersion(relativePath, expectedVersion);
            cancellationToken.ThrowIfCancellationRequested();
            if (executionContext is not null && !executionContext.TryContinue()) throw new OperationCanceledException("apply_edits cancelled before commit", cancellationToken);
            File.Move(temp, target, true);
            committed = true;
            _applyEditsStageForTests?.Invoke("after_commit");

            var after = _fileVersions.ReadVersioned(relativePath, FileMcpConstants.MaxFileBytes);
            result["committed"] = true;
            result["after_version"] = after.VersionToken;
            result["cancelled_after_commit"] = cancellationToken.IsCancellationRequested || (executionContext?.CancellationRequested ?? false);
            return result;
        }
        catch when (committed)
        {
            // Once atomic publish committed, callers must not receive a false rollback signal.
            var after = _fileVersions.ReadVersioned(relativePath, FileMcpConstants.MaxFileBytes);
            result["committed"] = true;
            result["after_version"] = after.VersionToken;
            result["cancelled_after_commit"] = true;
            return result;
        }
        finally
        {
            try { if (File.Exists(temp)) File.Delete(temp); } catch { }
        }
    }

    private sealed record CompiledEdit(int RequestIndex, int StartByte, int EndByte, byte[] Replacement);

    private static IReadOnlyList<CompiledEdit> CompileEdits(
        JsonArray edits,
        string coordinateSystem,
        string text,
        byte[] content,
        string? normalizedNewline)
    {
        var compiled = new List<CompiledEdit>(edits.Count);
        for (var i = 0; i < edits.Count; i++)
        {
            if (edits[i] is not JsonObject edit) throw new FileMcpException($"edits[{i}] must be an object");
            if (edit["replacement"] is not JsonValue replacementNode || !replacementNode.TryGetValue<string>(out var replacement) || replacement is null)
                throw new FileMcpException($"edits[{i}].replacement must be a string");
            if (normalizedNewline is not null) replacement = NormalizeNewlines(replacement, normalizedNewline);
            var replacementBytes = Encoding.UTF8.GetBytes(replacement);
            int startByte;
            int endByte;
            if (coordinateSystem == "byte")
            {
                startByte = RequiredEditInt(edit, "start_byte", i);
                endByte = RequiredEditInt(edit, "end_byte", i);
                if (startByte < 0 || endByte < startByte || endByte > content.Length)
                    throw new FileMcpException($"edits[{i}] byte range is out of bounds");
                EnsureUtf8Boundary(content, startByte, i);
                EnsureUtf8Boundary(content, endByte, i);
            }
            else
            {
                startByte = LineColumnToByte(text, RequiredPosition(edit, "start", i), i, "start");
                endByte = LineColumnToByte(text, RequiredPosition(edit, "end", i), i, "end");
                if (endByte < startByte) throw new FileMcpException($"edits[{i}] end precedes start");
            }
            compiled.Add(new CompiledEdit(i, startByte, endByte, replacementBytes));
        }

        var ordered = compiled.OrderBy(edit => edit.StartByte).ThenBy(edit => edit.EndByte).ThenBy(edit => edit.RequestIndex).ToList();
        for (var i = 1; i < ordered.Count; i++)
        {
            var previous = ordered[i - 1];
            var current = ordered[i];
            if (current.StartByte < previous.EndByte)
                throw new FileMcpException("apply_edits contains overlapping ranges");
            if (current.StartByte == previous.StartByte && (current.EndByte != current.StartByte || previous.EndByte != previous.StartByte))
                throw new FileMcpException("apply_edits contains overlapping ranges");
        }
        return ordered;
    }

    private static byte[] ApplyCompiledEdits(byte[] content, IReadOnlyList<CompiledEdit> edits, bool includeBom)
    {
        using var output = new MemoryStream();
        if (includeBom) output.Write([0xEF, 0xBB, 0xBF]);
        var cursor = 0;
        foreach (var edit in edits)
        {
            output.Write(content, cursor, edit.StartByte - cursor);
            output.Write(edit.Replacement);
            cursor = edit.EndByte;
        }
        output.Write(content, cursor, content.Length - cursor);
        return output.ToArray();
    }

    private static int RequiredEditInt(JsonObject edit, string key, int index)
    {
        if (edit[key] is JsonValue value && value.TryGetValue<int>(out var result)) return result;
        throw new FileMcpException($"edits[{index}].{key} must be an integer");
    }

    private static (int Line, int Column) RequiredPosition(JsonObject edit, string key, int index)
    {
        if (edit[key] is not JsonObject position) throw new FileMcpException($"edits[{index}].{key} must be an object");
        if (position["line"] is not JsonValue lineNode || !lineNode.TryGetValue<int>(out var line) ||
            position["column"] is not JsonValue columnNode || !columnNode.TryGetValue<int>(out var column))
            throw new FileMcpException($"edits[{index}].{key} requires integer line and column");
        return (line, column);
    }

    private static int LineColumnToByte(string text, (int Line, int Column) position, int editIndex, string label)
    {
        if (position.Line < 1 || position.Column < 1) throw new FileMcpException($"edits[{editIndex}].{label} line/column are 1-based");
        var line = 1;
        var column = 1;
        var charIndex = 0;
        var byteOffset = 0;
        while (true)
        {
            if (line == position.Line && column == position.Column) return byteOffset;
            if (charIndex >= text.Length)
                throw new FileMcpException($"edits[{editIndex}].{label} position is out of bounds");

            if (text[charIndex] == '\r')
            {
                if (line >= position.Line)
                    throw new FileMcpException($"edits[{editIndex}].{label} column is out of bounds");
                byteOffset += 1;
                charIndex++;
                if (charIndex < text.Length && text[charIndex] == '\n')
                {
                    byteOffset += 1;
                    charIndex++;
                }
                line++;
                column = 1;
                continue;
            }
            if (text[charIndex] == '\n')
            {
                if (line >= position.Line)
                    throw new FileMcpException($"edits[{editIndex}].{label} column is out of bounds");
                byteOffset += 1;
                charIndex++;
                line++;
                column = 1;
                continue;
            }

            var rune = Rune.GetRuneAt(text, charIndex);
            charIndex += rune.Utf16SequenceLength;
            byteOffset += rune.Utf8SequenceLength;
            column++;
        }
    }

    private static void EnsureUtf8Boundary(byte[] content, int offset, int editIndex)
    {
        if (offset == 0 || offset == content.Length) return;
        if ((content[offset] & 0xC0) == 0x80) throw new FileMcpException($"edits[{editIndex}] byte offset is not a UTF-8 boundary");
    }

    private static string NormalizeNewlines(string value, string newline) =>
        value.Replace("\r\n", "\n").Replace('\r', '\n').Replace("\n", newline);

    private static string DetectPreferredNewline(string text)
    {
        for (var i = 0; i < text.Length; i++)
        {
            if (text[i] == '\r') return i + 1 < text.Length && text[i + 1] == '\n' ? "\r\n" : "\r";
            if (text[i] == '\n') return "\n";
        }
        return "\n";
    }

    private static string PreviewUtf8(byte[] bytes, int maxBytes)
    {
        var slice = bytes.AsSpan(0, Math.Min(bytes.Length, maxBytes));
        var preview = Encoding.UTF8.GetString(slice);
        return bytes.Length > maxBytes ? preview + "\n[...preview truncated...]" : preview;
    }

    private async Task<JsonObject> ExecProcessAsync(
        string executable,
        IReadOnlyList<string> arguments,
        string cwd,
        IReadOnlyDictionary<string, string> environmentOverrides,
        int timeoutSeconds,
        int outputLimitBytes,
        PolicySnapshot preparedPolicy,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(executable)) throw new FileMcpException("executable must not be empty");
        if (executable.Length > 4_096) throw new FileMcpException("executable is too long");
        if (arguments.Count > 256) throw new FileMcpException("exec_process supports at most 256 arguments");
        if (arguments.Any(value => value.Length > 32_768)) throw new FileMcpException("exec_process argument exceeds 32768 characters");
        if (arguments.Sum(value => value.Length) > 32_768) throw new FileMcpException("exec_process total argument size exceeds 32768 characters");
        if (timeoutSeconds is < 1 or > ProcessRunner.MaxCommandTimeoutSeconds) throw new FileMcpException($"timeout_seconds must be 1..{ProcessRunner.MaxCommandTimeoutSeconds}");
        if (outputLimitBytes is < 1 or > FileMcpConstants.MaxToolProcessOutputBytes) throw new FileMcpException($"output_limit_bytes must be 1..{FileMcpConstants.MaxToolProcessOutputBytes}");

        var workdir = _resolver.Resolve(cwd);
        if (!Directory.Exists(workdir)) throw new FileMcpException($"No such working directory: {(string.IsNullOrEmpty(cwd) ? "." : cwd)}");
        var environment = _execEnvironment.Build(environmentOverrides);

        await _commandSlots.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            // Re-authorize immediately before the side effect so a prepared request cannot execute
            // after local policy generation/hash changes.
            _policy.Authorize("exec_process", preparedPolicy);
            var result = await ProcessRunner.RunAsync(
                executable,
                arguments,
                workdir,
                environment,
                timeoutSeconds,
                outputLimitBytes,
                cancellationToken).ConfigureAwait(false);
            var terminalState = result.Cancelled ? "cancelled" : result.TimedOut ? "timed_out" : "exited";
            return new JsonObject
            {
                ["terminal_state"] = terminalState,
                ["exit_code"] = result.ExitCode,
                ["stdout"] = result.Stdout,
                ["stderr"] = result.Stderr,
                ["timed_out"] = result.TimedOut,
                ["cancelled"] = result.Cancelled,
                ["stdout_truncated"] = result.StdoutTruncated,
                ["stderr_truncated"] = result.StderrTruncated,
                ["stdout_omitted_bytes"] = result.StdoutOmittedBytes,
                ["stderr_omitted_bytes"] = result.StderrOmittedBytes,
            };
        }
        finally { _commandSlots.Release(); }
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

    private static ToolCallOutput VersionedStringOutput(JsonObject value)
    {
        var text = value["result"]?.GetValue<string>() ?? "";
        return new ToolCallOutput(
            new JsonArray(new JsonObject { ["type"] = "text", ["text"] = text }),
            value);
    }

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
    private static JsonArray GetRequiredArray(JsonObject args, string key) => args[key] is JsonArray value ? value : throw new FileMcpException($"Missing or invalid argument: {key}");
    private static string GetString(JsonObject args, string key, string fallback) => args[key] is JsonValue value && value.TryGetValue<string>(out var result) ? result : fallback;
    private static bool GetBool(JsonObject args, string key, bool fallback) => args[key] is JsonValue value && value.TryGetValue<bool>(out var result) ? result : fallback;
    private static int GetInt(JsonObject args, string key, int fallback) => args[key] is JsonValue value && value.TryGetValue<int>(out var result) ? result : fallback;

    private static IReadOnlyList<string> GetStringArray(JsonObject args, string key)
    {
        if (args[key] is null) return [];
        if (args[key] is not JsonArray array) throw new FileMcpException($"Missing or invalid argument: {key}");
        if (array.Count > 256) throw new FileMcpException($"Argument {key} supports at most 256 items");
        var result = new List<string>(array.Count);
        foreach (var node in array)
        {
            if (node is not JsonValue value || !value.TryGetValue<string>(out var item) || item is null)
                throw new FileMcpException($"Missing or invalid argument: {key}");
            result.Add(item);
        }
        return result;
    }

    private static IReadOnlyDictionary<string, string> GetStringDictionary(JsonObject args, string key)
    {
        if (args[key] is null) return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (args[key] is not JsonObject obj) throw new FileMcpException($"Missing or invalid argument: {key}");
        if (obj.Count > ExecProcessEnvironmentAuthority.MaxOverrides) throw new FileMcpException($"Argument {key} supports at most {ExecProcessEnvironmentAuthority.MaxOverrides} entries");
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var pair in obj)
        {
            if (pair.Value is not JsonValue value || !value.TryGetValue<string>(out var item) || item is null)
                throw new FileMcpException($"Missing or invalid argument: {key}");
            result[pair.Key] = item;
        }
        return result;
    }

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
            var property = properties[pair.Key]!.AsObject();
            var type = property["type"]!.GetValue<string>();
            var valid = type switch
            {
                "string" => pair.Value is JsonValue stringValue && stringValue.TryGetValue<string>(out _),
                "boolean" => pair.Value is JsonValue boolValue && boolValue.TryGetValue<bool>(out _),
                "integer" => pair.Value is JsonValue intValue && intValue.TryGetValue<int>(out _),
                "array" => pair.Value is JsonArray,
                "object" => pair.Value is JsonObject,
                _ => true,
            };
            if (!valid) throw new FileMcpException($"Missing or invalid argument: {pair.Key}");
            if (type == "integer")
            {
                var number = pair.Value!.GetValue<int>();
                if (property["minimum"] is JsonValue min && number < min.GetValue<int>()) throw new FileMcpException($"Argument {pair.Key} must be >= {min.GetValue<int>()}");
                if (property["maximum"] is JsonValue max && number > max.GetValue<int>()) throw new FileMcpException($"Argument {pair.Key} must be <= {max.GetValue<int>()}");
            }
            else if (type == "array" && pair.Value is JsonArray array && property["maxItems"] is JsonValue maxItems && array.Count > maxItems.GetValue<int>())
            {
                throw new FileMcpException($"Argument {pair.Key} supports at most {maxItems.GetValue<int>()} items");
            }
            else if (type == "object" && pair.Value is JsonObject obj && property["maxProperties"] is JsonValue maxProperties && obj.Count > maxProperties.GetValue<int>())
            {
                throw new FileMcpException($"Argument {pair.Key} supports at most {maxProperties.GetValue<int>()} entries");
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
