using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed class RepositoryIntelligenceQueryOptions
{
    public int RepoMapSpillThresholdBytes { get; init; } = 256 * 1024;
    public TimeSpan ArtifactTtl { get; init; } = TimeSpan.FromHours(24);
    public Action<string>? StageForTests { get; init; }
}

internal sealed partial class LocalTools
{
    private readonly AuthenticatedCursorCodec _repositoryQueryCursors = new();
    private Func<ArtifactContentStore>? _repositoryQueryArtifactFactory;
    private RepositoryIntelligenceQueryOptions _repositoryQueryOptions = new();

    private void ConfigureRepositoryIntelligenceQuery(
        Func<ArtifactContentStore> artifactFactory,
        RepositoryIntelligenceQueryOptions? options)
    {
        _repositoryQueryArtifactFactory = artifactFactory;
        _repositoryQueryOptions = options ?? new RepositoryIntelligenceQueryOptions();
        if (_repositoryQueryOptions.RepoMapSpillThresholdBytes is < 1024 or > 8 * 1024 * 1024)
            throw new ArgumentOutOfRangeException(nameof(options), "Repo map spill threshold must be 1 KiB..8 MiB");
        if (_repositoryQueryOptions.ArtifactTtl <= TimeSpan.Zero || _repositoryQueryOptions.ArtifactTtl > TimeSpan.FromDays(7))
            throw new ArgumentOutOfRangeException(nameof(options), "Repository map artifact TTL must be positive and <= 7 days");
    }

    private async Task<JsonObject> RepoMapAsync(
        string repoPath,
        string cursor,
        int maxItems,
        bool allowContentRef,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        if (maxItems is < 1 or > 500) throw new FileMcpException("max_items must be 1..500");
        var snapshot = await CaptureRepositoryIntelligenceAsync(repoPath, context: context, cancellationToken: cancellationToken).ConfigureAwait(false);
        EnsureQuerySnapshotUsable(snapshot);
        var sourceStateId = RequiredSnapshotString(snapshot, "source_state_id");
        var files = SnapshotFiles(snapshot)
            .OrderBy(file => RequiredString(file, "path"), StringComparer.Ordinal)
            .ToArray();

        var optionsHash = AuthenticatedCursorCodec.StableHash(string.Join("\n", new[]
        {
            "repo-map-v1",
            NormalizeQueryRepoPath(repoPath),
            maxItems.ToString(CultureInfo.InvariantCulture),
        }));
        var generation = QueryGeneration(sourceStateId);
        var start = DecodePagePosition(cursor, "repo_map", optionsHash, generation);

        var items = new JsonArray();
        var index = start;
        for (; index < files.Length && items.Count < maxItems; index++)
        {
            if (context is not null && !context.TryOutputItem()) break;
            var file = files[index];
            var path = RequiredString(file, "path");
            items.Add(new JsonObject
            {
                ["path"] = path,
                ["language"] = file["language"]?.DeepClone(),
                ["size_bytes"] = file["size_bytes"]?.DeepClone(),
                ["supported_language"] = file["supported_language"]?.DeepClone(),
                ["symbol_count"] = (file["symbols"] as JsonArray)?.Count ?? 0,
                ["import_count"] = (file["imports"] as JsonArray)?.Count ?? 0,
                ["relation_count"] = CountRelationsForPath(snapshot, path),
            });
        }

        var budgetTruncated = context?.Truncated == true;
        string? nextCursor = null;
        if (index < files.Length && !budgetTruncated)
            nextCursor = EncodePagePosition("repo_map", optionsHash, generation, index);

        _repositoryQueryOptions.StageForTests?.Invoke("before_freshness_recheck");
        await RequireQueryFreshAsync(repoPath, sourceStateId, cancellationToken).ConfigureAwait(false);

        string? contentRef = null;
        string? blobId = null;
        long? expiresEpochMs = null;
        var artifactState = "not_requested";
        if (allowContentRef)
        {
            var fullMap = BuildFullMapArtifact(snapshot);
            var bytes = Encoding.UTF8.GetBytes(fullMap.ToJsonString(new JsonSerializerOptions { WriteIndented = false }));
            if (bytes.Length >= _repositoryQueryOptions.RepoMapSpillThresholdBytes)
            {
                artifactState = "unavailable";
                try
                {
                    var artifacts = _repositoryQueryArtifactFactory?.Invoke()
                        ?? throw new FileMcpException("Repository map artifact store is unavailable");
                    await using var input = new MemoryStream(bytes, writable: false);
                    var descriptor = await artifacts.PutAsync(
                        input,
                        ArtifactContentStore.WorkspaceAuthorityId(_resolver.Root),
                        ArtifactContentClasses.ToolOutput,
                        "application/vnd.filemcp.repository-map+json",
                        _repositoryQueryOptions.ArtifactTtl,
                        cancellationToken: cancellationToken).ConfigureAwait(false);
                    contentRef = descriptor.ContentRef;
                    blobId = descriptor.BlobId;
                    expiresEpochMs = descriptor.ExpiresEpochMs;
                    artifactState = "available";
                    try
                    {
                        _repositoryQueryOptions.StageForTests?.Invoke("after_artifact_publish");
                        await RequireQueryFreshAsync(repoPath, sourceStateId, cancellationToken).ConfigureAwait(false);
                    }
                    catch
                    {
                        try
                        {
                            await artifacts.DeleteAsync(
                                descriptor.ContentRef,
                                ArtifactContentStore.WorkspaceAuthorityId(_resolver.Root),
                                value => value == ArtifactContentClasses.ToolOutput,
                                CancellationToken.None).ConfigureAwait(false);
                        }
                        catch { }
                        throw;
                    }
                }
                catch (OperationCanceledException) { throw; }
                catch (FileMcpException ex) when (!ex.Message.Contains("stale", StringComparison.OrdinalIgnoreCase))
                {
                    artifactState = "unavailable";
                }
                catch (IOException)
                {
                    artifactState = "unavailable";
                }
            }
            else
            {
                artifactState = "below_threshold";
            }
        }

        return QueryEnvelope(snapshot, new JsonObject
        {
            ["query_kind"] = "repo_map",
            ["total_items"] = files.Length,
            ["start_index"] = start,
            ["returned_count"] = items.Count,
            ["items"] = items,
            ["next_cursor"] = nextCursor,
            ["partial"] = index < files.Length || budgetTruncated,
            ["truncated"] = budgetTruncated,
            ["truncation_reason"] = context?.TruncationReason ?? "none",
            ["artifact_state"] = artifactState,
            ["content_ref"] = contentRef,
            ["blob_id"] = blobId,
            ["expires_epoch_ms"] = expiresEpochMs,
        });
    }

    private async Task<JsonObject> SymbolSearchAsync(
        string repoPath,
        string query,
        string kind,
        bool caseSensitive,
        string cursor,
        int maxResults,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(query)) throw new FileMcpException("query must not be empty");
        if (query.Length > 512) throw new FileMcpException("query is too long");
        if (maxResults is < 1 or > 200) throw new FileMcpException("max_results must be 1..200");
        kind = kind.Trim();
        if (kind.Length > 64) throw new FileMcpException("kind is too long");

        var snapshot = await CaptureRepositoryIntelligenceAsync(repoPath, context: context, cancellationToken: cancellationToken).ConfigureAwait(false);
        EnsureQuerySnapshotUsable(snapshot);
        var sourceStateId = RequiredSnapshotString(snapshot, "source_state_id");
        var comparison = caseSensitive ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase;
        var supported = false;
        var matches = new List<(JsonObject Item, double Score, bool Exact)>();

        foreach (var file in SnapshotFiles(snapshot))
        {
            if (file["supported_language"]?.GetValue<bool>() == true) supported = true;
            var path = RequiredString(file, "path");
            if (file["symbols"] is not JsonArray symbols) continue;
            foreach (var node in symbols)
            {
                if (node is not JsonObject symbol) continue;
                var name = RequiredString(symbol, "name");
                var symbolKind = RequiredString(symbol, "kind");
                if (!string.IsNullOrEmpty(kind) && !string.Equals(symbolKind, kind, StringComparison.OrdinalIgnoreCase)) continue;
                var score = MatchScore(name, query, comparison);
                if (score <= 0) continue;
                matches.Add((new JsonObject
                {
                    ["path"] = path,
                    ["name"] = name,
                    ["kind"] = symbolKind,
                    ["line"] = symbol["line"]?.DeepClone(),
                    ["score"] = score,
                }, score, score >= 1.0));
            }
        }

        var ordered = matches
            .OrderByDescending(match => match.Score)
            .ThenBy(match => RequiredString(match.Item, "name"), StringComparer.Ordinal)
            .ThenBy(match => RequiredString(match.Item, "path"), StringComparer.Ordinal)
            .ThenBy(match => match.Item["line"]?.GetValue<int>() ?? 0)
            .ToArray();
        var exactCount = ordered.Count(match => match.Exact);

        var optionsHash = AuthenticatedCursorCodec.StableHash(string.Join("\n", new[]
        {
            "symbol-search-v1",
            NormalizeQueryRepoPath(repoPath),
            query,
            kind,
            caseSensitive ? "case:on" : "case:off",
            maxResults.ToString(CultureInfo.InvariantCulture),
        }));
        var generation = QueryGeneration(sourceStateId);
        var start = DecodePagePosition(cursor, "symbol_search", optionsHash, generation);
        var items = PageItems(ordered.Select(match => match.Item).ToArray(), start, maxResults, context, out var nextIndex);
        var budgetTruncated = context?.Truncated == true;
        var nextCursor = nextIndex < ordered.Length && !budgetTruncated
            ? EncodePagePosition("symbol_search", optionsHash, generation, nextIndex)
            : null;

        _repositoryQueryOptions.StageForTests?.Invoke("before_freshness_recheck");
        await RequireQueryFreshAsync(repoPath, sourceStateId, cancellationToken).ConfigureAwait(false);

        return QueryEnvelope(snapshot, new JsonObject
        {
            ["query_kind"] = "symbol_search",
            ["query"] = query,
            ["kind_filter"] = kind,
            ["symbol_support"] = supported,
            ["ambiguous"] = exactCount > 1,
            ["exact_match_count"] = exactCount,
            ["total_results"] = ordered.Length,
            ["returned_count"] = items.Count,
            ["results"] = items,
            ["next_cursor"] = nextCursor,
            ["partial"] = nextIndex < ordered.Length || budgetTruncated,
            ["truncated"] = budgetTruncated,
            ["truncation_reason"] = context?.TruncationReason ?? "none",
        });
    }

    private async Task<JsonObject> RelatedFilesAsync(
        string repoPath,
        string relativePath,
        double minScore,
        string cursor,
        int maxResults,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        var normalizedPath = NormalizeQueryRelativePath(relativePath);
        if (minScore is < 0 or > 1) throw new FileMcpException("min_score must be between 0 and 1");
        if (maxResults is < 1 or > 200) throw new FileMcpException("max_results must be 1..200");

        var snapshot = await CaptureRepositoryIntelligenceAsync(repoPath, context: context, cancellationToken: cancellationToken).ConfigureAwait(false);
        EnsureQuerySnapshotUsable(snapshot);
        var sourceStateId = RequiredSnapshotString(snapshot, "source_state_id");
        var paths = SnapshotFiles(snapshot).Select(file => RequiredString(file, "path")).ToHashSet(StringComparer.Ordinal);
        if (!paths.Contains(normalizedPath))
            throw new FileMcpException("related_files path is not present in the current repository intelligence generation");

        var related = new List<JsonObject>();
        if (snapshot["relations"] is JsonArray relations)
        {
            foreach (var node in relations)
            {
                if (node is not JsonObject relation) continue;
                var source = RequiredString(relation, "source");
                var target = RequiredString(relation, "target");
                var score = relation["score"]?.GetValue<double>() ?? 0;
                if (score < minScore) continue;
                if (source == normalizedPath)
                {
                    related.Add(RelationResult(relation, target, "outgoing"));
                }
                else if (target == normalizedPath)
                {
                    related.Add(RelationResult(relation, source, "incoming"));
                }
            }
        }

        var ordered = related
            .OrderByDescending(item => item["score"]?.GetValue<double>() ?? 0)
            .ThenBy(item => RequiredString(item, "path"), StringComparer.Ordinal)
            .ThenBy(item => RequiredString(item, "kind"), StringComparer.Ordinal)
            .ThenBy(item => RequiredString(item, "direction"), StringComparer.Ordinal)
            .ToArray();

        var optionsHash = AuthenticatedCursorCodec.StableHash(string.Join("\n", new[]
        {
            "related-files-v1",
            NormalizeQueryRepoPath(repoPath),
            normalizedPath,
            minScore.ToString("R", CultureInfo.InvariantCulture),
            maxResults.ToString(CultureInfo.InvariantCulture),
        }));
        var generation = QueryGeneration(sourceStateId);
        var start = DecodePagePosition(cursor, "related_files", optionsHash, generation);
        var items = PageItems(ordered, start, maxResults, context, out var nextIndex);
        var budgetTruncated = context?.Truncated == true;
        var nextCursor = nextIndex < ordered.Length && !budgetTruncated
            ? EncodePagePosition("related_files", optionsHash, generation, nextIndex)
            : null;

        _repositoryQueryOptions.StageForTests?.Invoke("before_freshness_recheck");
        await RequireQueryFreshAsync(repoPath, sourceStateId, cancellationToken).ConfigureAwait(false);

        return QueryEnvelope(snapshot, new JsonObject
        {
            ["query_kind"] = "related_files",
            ["relative_path"] = normalizedPath,
            ["min_score"] = minScore,
            ["total_results"] = ordered.Length,
            ["returned_count"] = items.Count,
            ["results"] = items,
            ["next_cursor"] = nextCursor,
            ["partial"] = nextIndex < ordered.Length || budgetTruncated,
            ["truncated"] = budgetTruncated,
            ["truncation_reason"] = context?.TruncationReason ?? "none",
        });
    }

    private static JsonObject QueryEnvelope(JsonObject snapshot, JsonObject query)
    {
        query["schema_version"] = "1.0.0";
        query["provider_id"] = snapshot["provider_id"]?.DeepClone();
        query["provider_version"] = snapshot["provider_version"]?.DeepClone();
        query["completeness"] = snapshot["completeness"]?.DeepClone();
        query["parser_profile_hash"] = snapshot["parser_profile_hash"]?.DeepClone();
        query["source_state_id"] = snapshot["source_state_id"]?.DeepClone();
        query["grants_authority"] = false;
        query["raw_source_persisted"] = false;
        query["generation_truncated"] = snapshot["truncated"]?.DeepClone();
        query["generation_truncation_reason"] = snapshot["truncation_reason"]?.DeepClone();
        return query;
    }

    private static JsonObject BuildFullMapArtifact(JsonObject snapshot)
    {
        var files = new JsonArray();
        foreach (var file in SnapshotFiles(snapshot).OrderBy(file => RequiredString(file, "path"), StringComparer.Ordinal))
            files.Add(file.DeepClone());
        var relations = snapshot["relations"]?.DeepClone() ?? new JsonArray();
        return new JsonObject
        {
            ["schema_version"] = "1.0.0",
            ["kind"] = "repository_map",
            ["provider_id"] = snapshot["provider_id"]?.DeepClone(),
            ["provider_version"] = snapshot["provider_version"]?.DeepClone(),
            ["completeness"] = snapshot["completeness"]?.DeepClone(),
            ["parser_profile_hash"] = snapshot["parser_profile_hash"]?.DeepClone(),
            ["source_state_id"] = snapshot["source_state_id"]?.DeepClone(),
            ["grants_authority"] = false,
            ["raw_source_persisted"] = false,
            ["files"] = files,
            ["relations"] = relations,
        };
    }

    private async Task RequireQueryFreshAsync(string repoPath, string expectedSourceStateId, CancellationToken cancellationToken)
    {
        var current = await CaptureSourceStateRefAsync(repoPath, null, cancellationToken).ConfigureAwait(false);
        var currentId = current["source_state_id"]?.GetValue<string>()
            ?? throw new FileMcpException("Repository intelligence query SourceStateRef is unavailable");
        if (!string.Equals(currentId, expectedSourceStateId, StringComparison.Ordinal))
            throw new FileMcpException("Repository intelligence query generation became stale");
    }

    private int DecodePagePosition(string cursor, string tool, string optionsHash, long generation)
    {
        if (string.IsNullOrWhiteSpace(cursor)) return 0;
        var position = _repositoryQueryCursors.Decode(
            cursor,
            tool,
            optionsHash,
            RepositoryQueryRootAuthorityId(),
            generation,
            DateTimeOffset.UtcNow);
        if (!int.TryParse(position, NumberStyles.None, CultureInfo.InvariantCulture, out var parsed) || parsed < 0)
            throw new FileMcpException("Invalid cursor position");
        return parsed;
    }

    private string EncodePagePosition(string tool, string optionsHash, long generation, int position) =>
        _repositoryQueryCursors.Encode(
            tool,
            optionsHash,
            RepositoryQueryRootAuthorityId(),
            generation,
            position.ToString(CultureInfo.InvariantCulture),
            DateTimeOffset.UtcNow.Add(AuthenticatedCursorCodec.DefaultMaxLifetime));

    private string RepositoryQueryRootAuthorityId()
    {
        var canonical = OperatingSystem.IsWindows() ? _resolver.Root.ToUpperInvariant() : _resolver.Root;
        return AuthenticatedCursorCodec.StableHash(canonical);
    }

    private static long QueryGeneration(string sourceStateId)
    {
        var hash = AuthenticatedCursorCodec.StableHash(sourceStateId);
        var value = Convert.ToUInt64(hash[..16], 16);
        return unchecked((long)(value & 0x7fff_ffff_ffff_ffffUL));
    }

    private static JsonArray PageItems(
        IReadOnlyList<JsonObject> values,
        int start,
        int maxItems,
        ToolExecutionContext? context,
        out int nextIndex)
    {
        if (start > values.Count) throw new FileMcpException("Cursor position is outside the current result set");
        var result = new JsonArray();
        var index = start;
        for (; index < values.Count && result.Count < maxItems; index++)
        {
            if (context is not null && !context.TryOutputItem()) break;
            result.Add(values[index].DeepClone());
        }
        nextIndex = index;
        return result;
    }

    private static double MatchScore(string value, string query, StringComparison comparison)
    {
        if (string.Equals(value, query, comparison)) return 1.0;
        if (value.StartsWith(query, comparison)) return 0.75;
        if (value.Contains(query, comparison)) return 0.5;
        return 0;
    }

    private static JsonObject RelationResult(JsonObject relation, string path, string direction) => new()
    {
        ["path"] = path,
        ["direction"] = direction,
        ["kind"] = relation["kind"]?.DeepClone(),
        ["score"] = relation["score"]?.DeepClone(),
        ["rank"] = relation["rank"]?.DeepClone(),
    };

    private static int CountRelationsForPath(JsonObject snapshot, string path)
    {
        if (snapshot["relations"] is not JsonArray relations) return 0;
        var count = 0;
        foreach (var node in relations)
        {
            if (node is not JsonObject relation) continue;
            if (RequiredString(relation, "source") == path || RequiredString(relation, "target") == path) count++;
        }
        return count;
    }

    private static JsonObject[] SnapshotFiles(JsonObject snapshot) =>
        snapshot["files"] is JsonArray files
            ? files.OfType<JsonObject>().ToArray()
            : [];

    private static string RequiredSnapshotString(JsonObject value, string key) =>
        value[key]?.GetValue<string>() is { Length: > 0 } result
            ? result
            : throw new FileMcpException($"Repository intelligence snapshot missing {key}");

    private static string RequiredString(JsonObject value, string key) =>
        value[key]?.GetValue<string>() is { } result
            ? result
            : throw new FileMcpException($"Repository intelligence metadata missing {key}");

    private static void EnsureQuerySnapshotUsable(JsonObject snapshot)
    {
        if (snapshot["source_state_id"] is null)
            throw new FileMcpException("Repository intelligence generation has no SourceStateRef");
        if (snapshot["grants_authority"]?.GetValue<bool>() != false)
            throw new FileMcpException("Repository intelligence authority invariant failed");
    }

    private static double GetDouble(JsonObject source, string key, double fallback)
    {
        if (source[key] is null) return fallback;
        if (source[key] is not JsonValue value || !value.TryGetValue<double>(out var parsed) || double.IsNaN(parsed) || double.IsInfinity(parsed))
            throw new FileMcpException($"{key} must be a finite number");
        return parsed;
    }

    private static string NormalizeQueryRepoPath(string value) =>
        value.Replace('\\', '/').Trim().Trim('/');

    private static string NormalizeQueryRelativePath(string value)
    {
        var normalized = value.Replace('\\', '/').Trim();
        if (normalized.Length == 0 || normalized.StartsWith("/", StringComparison.Ordinal) ||
            (normalized.Length >= 3 && char.IsLetter(normalized[0]) && normalized[1] == ':' && normalized[2] == '/'))
            throw new FileMcpException("relative_path must be a repository-relative path");
        var parts = normalized.Split('/', StringSplitOptions.None);
        if (parts.Any(part => part is "" or "." or ".."))
            throw new FileMcpException("relative_path contains an invalid path segment");
        return string.Join("/", parts);
    }
}
