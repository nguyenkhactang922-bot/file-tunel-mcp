using System.Text;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed class BatchFileService
{
    internal const int MaxBatchEntries = 1024;
    internal const int DefaultReadBytes = 64 * 1024;
    internal const int MaxPerEntryBytes = 50 * 1024 * 1024;

    private readonly SafePathResolver _resolver;
    private readonly FileVersionService _versions;
    private readonly Func<ArtifactContentStore> _artifactFactory;
    private readonly string _workspaceAuthorityId;
    private readonly Action<string, int>? _stageForTests;
    private ArtifactContentStore? _artifacts;

    public BatchFileService(
        SafePathResolver resolver,
        FileVersionService versions,
        Func<ArtifactContentStore>? artifactFactory = null,
        Action<string, int>? stageForTests = null)
    {
        _resolver = resolver;
        _versions = versions;
        _workspaceAuthorityId = ArtifactContentStore.WorkspaceAuthorityId(resolver.Root);
        _stageForTests = stageForTests;
        _artifactFactory = artifactFactory ?? (() => new ArtifactContentStore(new ArtifactContentStoreOptions
        {
            WorkspaceRootForIsolation = resolver.Root,
        }));
    }

    public JsonObject Stat(JsonArray paths, ToolExecutionContext? context)
    {
        using var owned = context is null ? ToolExecutionContext.Create(null) : null;
        var effective = context ?? owned!;
        if (paths.Count == 0) throw new FileMcpException("paths must contain at least one entry");
        if (paths.Count > MaxBatchEntries) throw new FileMcpException($"paths may contain at most {MaxBatchEntries} entries");

        var entries = new JsonArray();
        var completed = 0;

        for (var index = 0; index < paths.Count; index++)
        {
            if (!effective.TryVisitEntry()) break;

            var requested = RequiredPath(paths[index], "paths", index);
            JsonObject item;
            try
            {
                var target = _resolver.Resolve(requested);
                if (File.Exists(target))
                {
                    var info = new FileInfo(target);
                    if (!effective.TryScanFile(info.Length))
                    {
                        item = ErrorEntry(requested, "budget_exhausted", "Aggregate batch budget exhausted while versioning file");
                        if (effective.TryOutputItem()) entries.Add(item);
                        break;
                    }

                    var versioned = _versions.ReadVersioned(requested, MaxPerEntryBytes);
                    item = new JsonObject
                    {
                        ["path"] = requested,
                        ["state"] = "ok",
                        ["entry_type"] = "file",
                        ["size_bytes"] = versioned.SizeBytes,
                        ["modified_utc"] = info.LastWriteTimeUtc.ToString("O"),
                        ["version"] = versioned.VersionToken,
                        ["version_strength"] = "content",
                    };
                }
                else if (Directory.Exists(target))
                {
                    var info = new DirectoryInfo(target);
                    item = new JsonObject
                    {
                        ["path"] = requested,
                        ["state"] = "ok",
                        ["entry_type"] = "directory",
                        ["size_bytes"] = 0,
                        ["modified_utc"] = info.LastWriteTimeUtc.ToString("O"),
                    };
                }
                else
                {
                    item = ErrorEntry(requested, "not_found", "Path does not exist");
                }
            }
            catch (Exception ex) when (ex is FileMcpException or IOException or UnauthorizedAccessException)
            {
                item = ErrorEntry(requested, ErrorCode(ex), PublicError(ex));
            }

            if (!effective.TryOutputItem()) break;
            entries.Add(item);
            completed++;
            _stageForTests?.Invoke("after_entry", index);
        }

        return Summary("batch_stat", paths.Count, completed, entries, effective);
    }

    public async Task<JsonObject> ReadAsync(
        JsonArray requests,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        using var owned = context is null ? ToolExecutionContext.Create(null, cancellationToken) : null;
        var effective = context ?? owned!;
        if (requests.Count == 0) throw new FileMcpException("requests must contain at least one entry");
        if (requests.Count > MaxBatchEntries) throw new FileMcpException($"requests may contain at most {MaxBatchEntries} entries");

        var entries = new JsonArray();
        var completed = 0;

        for (var index = 0; index < requests.Count; index++)
        {
            if (!effective.TryVisitEntry()) break;
            var request = RequiredRequest(requests[index], index);
            var path = RequiredRequestString(request, "relative_path", index);
            var maxBytes = OptionalPositiveInt(request, "max_bytes", DefaultReadBytes, MaxPerEntryBytes);
            var allowContentRef = OptionalBool(request, "allow_content_ref", false);

            JsonObject item;
            try
            {
                var target = _resolver.Resolve(path);
                if (!File.Exists(target))
                {
                    item = ErrorEntry(path, Directory.Exists(target) ? "not_file" : "not_found",
                        Directory.Exists(target) ? "Path is not a file" : "Path does not exist");
                }
                else
                {
                    var info = new FileInfo(target);
                    if (!effective.TryScanFile(info.Length))
                    {
                        item = ErrorEntry(path, "budget_exhausted", "Aggregate batch budget exhausted while reading file");
                        if (effective.TryOutputItem()) entries.Add(item);
                        break;
                    }

                    cancellationToken.ThrowIfCancellationRequested();
                    var versioned = _versions.ReadVersioned(path, MaxPerEntryBytes);
                    _stageForTests?.Invoke("after_versioned", index);
                    if (versioned.SizeBytes <= maxBytes)
                    {
                        item = new JsonObject
                        {
                            ["path"] = path,
                            ["state"] = "ok",
                            ["delivery"] = "inline",
                            ["content"] = Encoding.UTF8.GetString(versioned.Data),
                            ["size_bytes"] = versioned.SizeBytes,
                            ["version"] = versioned.VersionToken,
                            ["version_strength"] = "content",
                        };
                    }
                    else if (allowContentRef)
                    {
                        await using var stream = new MemoryStream(versioned.Data, writable: false);
                        var artifact = await Artifacts.PutAsync(
                            stream,
                            _workspaceAuthorityId,
                            ArtifactContentClasses.ToolOutput,
                            "application/octet-stream",
                            cancellationToken: cancellationToken).ConfigureAwait(false);
                        item = new JsonObject
                        {
                            ["path"] = path,
                            ["state"] = "ok",
                            ["delivery"] = "content_ref",
                            ["content_ref"] = artifact.ContentRef,
                            ["blob_id"] = artifact.BlobId,
                            ["expires_epoch_ms"] = artifact.ExpiresEpochMs,
                            ["size_bytes"] = versioned.SizeBytes,
                            ["version"] = versioned.VersionToken,
                            ["version_strength"] = "content",
                        };
                    }
                    else
                    {
                        item = new JsonObject
                        {
                            ["path"] = path,
                            ["state"] = "too_large",
                            ["delivery"] = "none",
                            ["size_bytes"] = versioned.SizeBytes,
                            ["max_bytes"] = maxBytes,
                            ["version"] = versioned.VersionToken,
                            ["version_strength"] = "content",
                        };
                    }
                }
            }
            catch (OperationCanceledException)
            {
                effective.MarkTruncated("cancelled");
                break;
            }
            catch (Exception ex) when (ex is FileMcpException or IOException or UnauthorizedAccessException)
            {
                item = ErrorEntry(path, ErrorCode(ex), PublicError(ex));
            }

            if (!effective.TryOutputItem()) break;
            entries.Add(item);
            completed++;
            _stageForTests?.Invoke("after_entry", index);
        }

        return Summary("batch_read", requests.Count, completed, entries, effective);
    }

    private ArtifactContentStore Artifacts => _artifacts ??= _artifactFactory();

    private static JsonObject Summary(
        string operation,
        int requested,
        int completed,
        JsonArray entries,
        ToolExecutionContext context)
    {
        var reason = context.TruncationReason;
        var partial = completed < requested || context.Truncated;
        return new JsonObject
        {
            ["operation"] = operation,
            ["requested_count"] = requested,
            ["completed_count"] = completed,
            ["partial"] = partial,
            ["cancelled"] = reason == "cancelled",
            ["truncated"] = context.Truncated,
            ["truncation_reason"] = reason,
            ["entries"] = entries,
        };
    }

    private static JsonObject ErrorEntry(string path, string code, string message) => new()
    {
        ["path"] = path,
        ["state"] = "error",
        ["error_code"] = code,
        ["error"] = message,
    };

    private static string ErrorCode(Exception ex)
    {
        var message = ex.Message;
        if (message.Contains("outside the shared directory", StringComparison.OrdinalIgnoreCase)) return "path_outside_root";
        if (message.Contains("No such file", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("does not exist", StringComparison.OrdinalIgnoreCase)) return "not_found";
        if (message.Contains("larger than", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("too large", StringComparison.OrdinalIgnoreCase)) return "too_large";
        if (message.Contains("changed", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("replaced", StringComparison.OrdinalIgnoreCase)) return "file_changed";
        if (message.Contains("quota", StringComparison.OrdinalIgnoreCase)) return "artifact_quota";
        if (message.Contains("ContentRef", StringComparison.OrdinalIgnoreCase)) return "artifact_unavailable";
        if (ex is UnauthorizedAccessException) return "access_denied";
        return "io_error";
    }

    private static string PublicError(Exception ex)
    {
        var message = ex.Message.Trim();
        return string.IsNullOrEmpty(message) ? "Batch entry failed" : message;
    }

    private static string RequiredPath(JsonNode? node, string collectionName, int index)
    {
        if (node is not JsonValue value || !value.TryGetValue<string>(out var path) || string.IsNullOrWhiteSpace(path))
            throw new FileMcpException($"{collectionName}[{index}] must be a non-empty string path");
        return path;
    }

    private static JsonObject RequiredRequest(JsonNode? node, int index)
    {
        var request = node as JsonObject ?? throw new FileMcpException($"requests[{index}] must be an object");
        var allowed = new HashSet<string>(StringComparer.Ordinal) { "relative_path", "max_bytes", "allow_content_ref" };
        foreach (var key in request.Select(pair => pair.Key))
        {
            if (!allowed.Contains(key))
                throw new FileMcpException($"requests[{index}] contains unknown field: {key}");
        }
        return request;
    }

    private static string RequiredRequestString(JsonObject request, string key, int index)
    {
        if (request[key] is not JsonValue value || !value.TryGetValue<string>(out var result) || string.IsNullOrWhiteSpace(result))
            throw new FileMcpException($"requests[{index}].{key} must be a non-empty string");
        return result;
    }

    private static int OptionalPositiveInt(JsonObject request, string key, int fallback, int maximum)
    {
        if (request[key] is null) return fallback;
        if (request[key] is not JsonValue value || !value.TryGetValue<int>(out var result) || result <= 0 || result > maximum)
            throw new FileMcpException($"{key} must be an integer between 1 and {maximum}");
        return result;
    }

    private static bool OptionalBool(JsonObject request, string key, bool fallback)
    {
        if (request[key] is null) return fallback;
        if (request[key] is not JsonValue value || !value.TryGetValue<bool>(out var result))
            throw new FileMcpException($"{key} must be a boolean");
        return result;
    }
}
