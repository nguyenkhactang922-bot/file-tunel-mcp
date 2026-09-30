using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed class WorkspaceCheckpointOptions
{
    public string? MetadataRootDirectory { get; init; }
    public TimeSpan DefaultTtl { get; init; } = TimeSpan.FromHours(24);
    public TimeSpan MaxTtl { get; init; } = TimeSpan.FromDays(7);
    public int MaxEntries { get; init; } = 5_000;
    public long MaxTotalBytes { get; init; } = 50_000_000;
    public long MaxSingleFileBytes { get; init; } = 32L * 1024 * 1024;
    public Func<DateTimeOffset> UtcNow { get; init; } = () => DateTimeOffset.UtcNow;
    internal Action<string>? StageForTests { get; init; }
}

internal sealed class WorkspaceCheckpointService
{
    private const int SchemaVersion = 1;
    private readonly SafePathResolver _resolver;
    private readonly Func<ArtifactContentStore> _artifactFactory;
    private readonly ServerPolicy _policy;
    private readonly WorkspaceCheckpointOptions _options;
    private readonly Func<string, CancellationToken, Task<string>> _resolveRepo;
    private readonly Func<string, IReadOnlyList<string>, int, bool, CancellationToken, Task<string>> _runGit;
    private readonly Func<string, string, CancellationToken, Task<byte[]?>> _readIndexBlob;
    private readonly Func<string, IReadOnlyList<string>?, CancellationToken, Task<JsonObject>> _captureSourceState;
    private readonly string _workspaceAuthorityId;
    private readonly string _metadataRoot;
    private readonly string _indexPath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly JsonSerializerOptions _json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };
    private bool _initialized;
    private List<CheckpointRecord> _records = [];

    internal WorkspaceCheckpointService(
        SafePathResolver resolver,
        Func<ArtifactContentStore> artifactFactory,
        ServerPolicy policy,
        Func<string, CancellationToken, Task<string>> resolveRepo,
        Func<string, IReadOnlyList<string>, int, bool, CancellationToken, Task<string>> runGit,
        Func<string, string, CancellationToken, Task<byte[]?>> readIndexBlob,
        Func<string, IReadOnlyList<string>?, CancellationToken, Task<JsonObject>> captureSourceState,
        WorkspaceCheckpointOptions? options = null)
    {
        _resolver = resolver;
        _artifactFactory = artifactFactory;
        _policy = policy;
        _resolveRepo = resolveRepo;
        _runGit = runGit;
        _readIndexBlob = readIndexBlob;
        _captureSourceState = captureSourceState;
        _options = options ?? new WorkspaceCheckpointOptions();
        ValidateOptions(_options);
        _workspaceAuthorityId = ArtifactContentStore.WorkspaceAuthorityId(_resolver.Root);
        var baseRoot = _options.MetadataRootDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FileMCP",
            "checkpoints-v1");
        _metadataRoot = Path.Combine(Path.GetFullPath(baseRoot), _workspaceAuthorityId["sha256:".Length..]);
        _indexPath = Path.Combine(_metadataRoot, "index-v1.json");
    }

    private ArtifactContentStore Artifacts => _artifactFactory();

    internal async Task<JsonObject> CaptureAsync(
        string repoPath,
        bool includeUntracked,
        bool includeIgnored,
        bool includeGenerated,
        int ttlSeconds,
        int maxFiles,
        long maxTotalBytes,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        RequireContinue(context, cancellationToken);
        var ttl = ResolveTtl(ttlSeconds);
        var effectiveMaxFiles = maxFiles == 0 ? _options.MaxEntries : maxFiles;
        var effectiveMaxBytes = maxTotalBytes == 0 ? _options.MaxTotalBytes : maxTotalBytes;
        if (effectiveMaxFiles < 1 || effectiveMaxFiles > _options.MaxEntries)
            throw new FileMcpException($"max_files must be between 1 and {_options.MaxEntries}");
        if (effectiveMaxBytes < 1 || effectiveMaxBytes > _options.MaxTotalBytes)
            throw new FileMcpException($"max_total_bytes must be between 1 and {_options.MaxTotalBytes}");

        var repo = await _resolveRepo(repoPath, cancellationToken).ConfigureAwait(false);
        var sourceBefore = await _captureSourceState(repoPath, null, cancellationToken).ConfigureAwait(false);
        var sourceStateId = RequiredString(sourceBefore, "source_state_id");
        var headOid = OptionalString(sourceBefore, "head_oid");
        var indexFingerprint = RequiredString(sourceBefore, "index_fingerprint");

        var staged = SplitNul(await _runGit(repo,
            ["diff", "--cached", "--name-only", "--diff-filter=ACMRD", "-z", "--"],
            FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false));
        var unstaged = SplitNul(await _runGit(repo,
            ["diff", "--name-only", "--diff-filter=ACMRD", "-z", "--"],
            FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false));
        var untracked = includeUntracked
            ? SplitNul(await _runGit(repo,
                ["ls-files", "--others", "--exclude-standard", "-z", "--"],
                FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false))
            : [];
        var ignored = includeIgnored
            ? SplitNul(await _runGit(repo,
                ["ls-files", "--others", "--ignored", "--exclude-standard", "-z", "--"],
                FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false))
            : [];

        var stagedSet = staged.ToHashSet(StringComparer.Ordinal);
        var unstagedSet = unstaged.ToHashSet(StringComparer.Ordinal);
        var untrackedSet = untracked.ToHashSet(StringComparer.Ordinal);
        var ignoredSet = ignored.ToHashSet(StringComparer.Ordinal);
        var allPaths = stagedSet.Concat(unstagedSet).Concat(untrackedSet).Concat(ignoredSet)
            .Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
        if (allPaths.Length > effectiveMaxFiles)
            throw new FileMcpException($"Checkpoint file count exceeds max_files ({effectiveMaxFiles})");
        var captureGuardBefore = await _captureSourceState(repoPath, allPaths, cancellationToken).ConfigureAwait(false);
        var captureGuardStateId = RequiredString(captureGuardBefore, "source_state_id");

        var repoFull = Path.GetFullPath(repo).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var repoPrefix = repoFull + Path.DirectorySeparatorChar;
        var createdRefs = new List<string>();
        var entries = new List<CheckpointManifestEntry>(allPaths.Length);
        long totalBytes = 0;

        try
        {
            foreach (var path in allPaths)
            {
                RequireContinue(context, cancellationToken);
                ValidateRepoRelativePath(path);
                var full = Path.GetFullPath(Path.Combine(repoFull, path.Replace('/', Path.DirectorySeparatorChar)));
                if (!full.StartsWith(repoPrefix, OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal))
                    throw new FileMcpException("Checkpoint path escaped the repository");
                if (File.Exists(full) || Directory.Exists(full))
                {
                    var lexicalAttributes = File.GetAttributes(full);
                    if ((lexicalAttributes & FileAttributes.ReparsePoint) != 0)
                        throw new FileMcpException($"Checkpoint refuses symlink/reparse entry: {path}");
                }
                var sharedRelative = _resolver.RelativePath(full);
                var resolved = _resolver.Resolve(sharedRelative);
                var exists = File.Exists(resolved);

                if (exists)
                {
                    var attributes = File.GetAttributes(resolved);
                    if ((attributes & FileAttributes.Directory) != 0)
                        throw new FileMcpException($"Checkpoint only captures regular files: {path}");
                }
                else if (Directory.Exists(resolved))
                {
                    throw new FileMcpException($"Checkpoint only captures regular files: {path}");
                }

                var generated = IsGeneratedPath(path);
                string? indexRef = null;
                string? indexHash = null;
                long indexBytes = 0;
                string? indexExcludedReason = null;
                if (stagedSet.Contains(path))
                {
                    if (generated && !includeGenerated)
                    {
                        indexExcludedReason = "generated";
                    }
                    else
                    {
                        var indexData = await _readIndexBlob(repo, path, cancellationToken).ConfigureAwait(false);
                        if (indexData is not null)
                        {
                            if (indexData.LongLength > _options.MaxSingleFileBytes)
                            {
                                indexExcludedReason = "oversized";
                            }
                            else
                            {
                                EnforcePayloadBounds(path, indexData.LongLength, ref totalBytes, effectiveMaxBytes);
                                await using var indexStream = new MemoryStream(indexData, writable: false);
                                var descriptor = await Artifacts.PutAsync(
                                    indexStream, _workspaceAuthorityId, ArtifactContentClasses.Checkpoint,
                                    "application/octet-stream", ttl, cancellationToken: cancellationToken).ConfigureAwait(false);
                                createdRefs.Add(descriptor.ContentRef);
                                indexRef = descriptor.ContentRef;
                                indexHash = descriptor.BlobId;
                                indexBytes = descriptor.SizeBytes;
                            }
                        }
                    }
                }

                string? worktreeRef = null;
                string? worktreeHash = null;
                long worktreeBytes = 0;
                string? worktreeExcludedReason = null;
                if ((stagedSet.Contains(path) || unstagedSet.Contains(path) || untrackedSet.Contains(path) || ignoredSet.Contains(path)) && exists)
                {
                    var info = new FileInfo(resolved);
                    if (generated && !includeGenerated)
                    {
                        worktreeExcludedReason = "generated";
                    }
                    else if (info.Length > _options.MaxSingleFileBytes)
                    {
                        worktreeExcludedReason = "oversized";
                    }
                    else
                    {
                        EnforcePayloadBounds(path, info.Length, ref totalBytes, effectiveMaxBytes);
                        await using var stream = new FileStream(
                            resolved, FileMode.Open, FileAccess.Read, FileShare.Read, 128 * 1024,
                            FileOptions.Asynchronous | FileOptions.SequentialScan);
                        var descriptor = await Artifacts.PutAsync(
                            stream, _workspaceAuthorityId, ArtifactContentClasses.Checkpoint,
                            "application/octet-stream", ttl, cancellationToken: cancellationToken).ConfigureAwait(false);
                        createdRefs.Add(descriptor.ContentRef);
                        worktreeRef = descriptor.ContentRef;
                        worktreeHash = descriptor.BlobId;
                        worktreeBytes = descriptor.SizeBytes;
                    }
                }

                entries.Add(new CheckpointManifestEntry
                {
                    RelativePath = path,
                    Staged = stagedSet.Contains(path),
                    Unstaged = unstagedSet.Contains(path),
                    Untracked = untrackedSet.Contains(path),
                    Ignored = ignoredSet.Contains(path),
                    Generated = generated,
                    IndexContentRef = indexRef,
                    IndexSha256 = indexHash,
                    IndexSizeBytes = indexBytes,
                    IndexExcludedReason = indexExcludedReason,
                    WorktreeContentRef = worktreeRef,
                    WorktreeSha256 = worktreeHash,
                    WorktreeSizeBytes = worktreeBytes,
                    WorktreeExcludedReason = worktreeExcludedReason,
                    WorktreeExists = exists,
                });
            }

            _options.StageForTests?.Invoke("after_payloads");
            var sourceAfter = await _captureSourceState(repoPath, null, cancellationToken).ConfigureAwait(false);
            var captureGuardAfter = await _captureSourceState(repoPath, allPaths, cancellationToken).ConfigureAwait(false);
            if (!string.Equals(sourceStateId, RequiredString(sourceAfter, "source_state_id"), StringComparison.Ordinal) ||
                !string.Equals(captureGuardStateId, RequiredString(captureGuardAfter, "source_state_id"), StringComparison.Ordinal))
                throw new FileMcpException("Repository changed while checkpoint capture was in progress");

            _policy.Authorize("checkpoint_capture", preparedPolicy);
            RequireContinue(context, cancellationToken);

            var now = _options.UtcNow();
            var manifest = new CheckpointManifest
            {
                SchemaVersion = SchemaVersion,
                WorkspaceAuthorityId = _workspaceAuthorityId,
                RepositoryRelativePath = _resolver.RelativePath(repo),
                HeadOid = headOid,
                IndexFingerprint = indexFingerprint,
                SourceStateId = sourceStateId,
                CreatedEpochMs = now.ToUnixTimeMilliseconds(),
                ExpiresEpochMs = now.Add(ttl).ToUnixTimeMilliseconds(),
                IncludeUntracked = includeUntracked,
                IncludeIgnored = includeIgnored,
                IncludeGenerated = includeGenerated,
                StagedCount = entries.Count(e => e.Staged),
                UnstagedCount = entries.Count(e => e.Unstaged),
                UntrackedCount = entries.Count(e => e.Untracked),
                IgnoredCount = entries.Count(e => e.Ignored),
                ExcludedCount = entries.Count(e => e.IndexExcludedReason is not null || e.WorktreeExcludedReason is not null),
                TotalBytes = totalBytes,
                Entries = entries,
            };
            var manifestBytes = JsonSerializer.SerializeToUtf8Bytes(manifest, _json);
            await using var manifestStream = new MemoryStream(manifestBytes, writable: false);
            var packaged = await Artifacts.PutAsync(
                manifestStream, _workspaceAuthorityId, ArtifactContentClasses.Checkpoint,
                "application/vnd.filemcp.checkpoint+json", ttl, cancellationToken: cancellationToken).ConfigureAwait(false);
            createdRefs.Add(packaged.ContentRef);

            var record = new CheckpointRecord
            {
                CheckpointRef = packaged.ContentRef,
                ManifestHash = packaged.BlobId,
                WorkspaceAuthorityId = _workspaceAuthorityId,
                RepositoryRelativePath = manifest.RepositoryRelativePath,
                HeadOid = headOid,
                SourceStateId = sourceStateId,
                CreatedEpochMs = manifest.CreatedEpochMs,
                ExpiresEpochMs = manifest.ExpiresEpochMs,
                StagedCount = manifest.StagedCount,
                UnstagedCount = manifest.UnstagedCount,
                UntrackedCount = manifest.UntrackedCount,
                IgnoredCount = manifest.IgnoredCount,
                ExcludedCount = manifest.ExcludedCount,
                EntryCount = entries.Count,
                TotalBytes = totalBytes,
            };
            await AddRecordAsync(record, cancellationToken).ConfigureAwait(false);
            _options.StageForTests?.Invoke("after_record");
            return RecordMetadata(record, expired: false, manifest);
        }
        catch
        {
            foreach (var contentRef in createdRefs.AsEnumerable().Reverse())
            {
                try
                {
                    await Artifacts.DeleteAsync(
                        contentRef, _workspaceAuthorityId,
                        value => value == ArtifactContentClasses.Checkpoint,
                        CancellationToken.None).ConfigureAwait(false);
                }
                catch { }
            }
            throw;
        }
    }

    internal async Task<JsonObject> ListAsync(int maxItems, CancellationToken cancellationToken)
    {
        if (maxItems < 1 || maxItems > 1000)
            throw new FileMcpException("max_items must be between 1 and 1000");
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await PruneExpiredAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var items = new JsonArray();
            foreach (var record in _records.OrderByDescending(r => r.CreatedEpochMs).Take(maxItems))
                items.Add(RecordMetadata(record, expired: false));
            return new JsonObject
            {
                ["items"] = items,
                ["count"] = items.Count,
                ["workspace_authority_id"] = _workspaceAuthorityId,
            };
        }
        finally { _gate.Release(); }
    }

    internal async Task<JsonObject> GetAsync(string checkpointRef, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(checkpointRef))
            throw new FileMcpException("checkpoint_ref must be non-empty");
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await PruneExpiredAsync(cancellationToken).ConfigureAwait(false);
        CheckpointRecord record;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            record = _records.SingleOrDefault(r => r.CheckpointRef == checkpointRef)
                ?? throw new FileMcpException("Unknown or expired checkpoint_ref");
        }
        finally { _gate.Release(); }
        var manifest = await LoadManifestAsync(record, cancellationToken).ConfigureAwait(false);
        return RecordMetadata(record, expired: false, manifest);
    }

    internal async Task<JsonObject> DeleteAsync(
        string checkpointRef,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        RequireContinue(context, cancellationToken);
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        CheckpointRecord record;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            record = _records.SingleOrDefault(r => r.CheckpointRef == checkpointRef)
                ?? throw new FileMcpException("Unknown or expired checkpoint_ref");
        }
        finally { _gate.Release(); }

        var manifest = await LoadManifestAsync(record, cancellationToken).ConfigureAwait(false);
        _policy.Authorize("checkpoint_delete", preparedPolicy);
        RequireContinue(context, cancellationToken);

        foreach (var contentRef in ManifestContentRefs(manifest).Append(record.CheckpointRef).Distinct(StringComparer.Ordinal))
        {
            try
            {
                await Artifacts.DeleteAsync(
                    contentRef, _workspaceAuthorityId,
                    value => value == ArtifactContentClasses.Checkpoint,
                    cancellationToken).ConfigureAwait(false);
            }
            catch (FileMcpException) { }
        }

        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var candidate = _records.Where(r => r.CheckpointRef != checkpointRef).ToList();
            PersistIndex(candidate);
            _records = candidate;
        }
        finally { _gate.Release(); }
        return new JsonObject
        {
            ["checkpoint_ref"] = checkpointRef,
            ["deleted"] = true,
        };
    }

    private async Task<CheckpointManifest> LoadManifestAsync(CheckpointRecord record, CancellationToken cancellationToken)
    {
        await using var memory = new MemoryStream();
        await Artifacts.CopyToAsync(
            record.CheckpointRef, _workspaceAuthorityId,
            value => value == ArtifactContentClasses.Checkpoint,
            memory, cancellationToken).ConfigureAwait(false);
        var descriptor = await Artifacts.ResolveAsync(
            record.CheckpointRef, _workspaceAuthorityId,
            value => value == ArtifactContentClasses.Checkpoint,
            cancellationToken).ConfigureAwait(false);
        if (!string.Equals(descriptor.BlobId, record.ManifestHash, StringComparison.Ordinal))
            throw new FileMcpException("Checkpoint manifest digest mismatch");
        var manifest = JsonSerializer.Deserialize<CheckpointManifest>(memory.ToArray(), _json)
            ?? throw new FileMcpException("Checkpoint manifest is invalid");
        ValidateManifest(manifest);
        if (!string.Equals(manifest.WorkspaceAuthorityId, _workspaceAuthorityId, StringComparison.Ordinal))
            throw new FileMcpException("Checkpoint workspace identity mismatch");
        return manifest;
    }

    private async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (_initialized) return;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_initialized) return;
            Directory.CreateDirectory(_metadataRoot);
            if (File.Exists(_indexPath))
            {
                var bytes = await File.ReadAllBytesAsync(_indexPath, cancellationToken).ConfigureAwait(false);
                _records = JsonSerializer.Deserialize<List<CheckpointRecord>>(bytes, _json) ?? [];
                foreach (var record in _records) ValidateRecord(record);
            }
            _initialized = true;
        }
        finally { _gate.Release(); }
    }

    private async Task AddRecordAsync(CheckpointRecord record, CancellationToken cancellationToken)
    {
        ValidateRecord(record);
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var candidate = _records.Where(r => r.ExpiresEpochMs > _options.UtcNow().ToUnixTimeMilliseconds()).ToList();
            candidate.Add(record);
            PersistIndex(candidate);
            _records = candidate;
        }
        finally { _gate.Release(); }
    }

    private async Task PruneExpiredAsync(CancellationToken cancellationToken)
    {
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var now = _options.UtcNow().ToUnixTimeMilliseconds();
            var candidate = _records.Where(r => r.ExpiresEpochMs > now).ToList();
            if (candidate.Count != _records.Count)
            {
                PersistIndex(candidate);
                _records = candidate;
            }
        }
        finally { _gate.Release(); }
        await Artifacts.CollectGarbageAsync(cancellationToken).ConfigureAwait(false);
    }

    private void PersistIndex(List<CheckpointRecord> records)
    {
        Directory.CreateDirectory(_metadataRoot);
        var temp = _indexPath + ".tmp-" + Guid.NewGuid().ToString("N");
        var bytes = JsonSerializer.SerializeToUtf8Bytes(records, _json);
        File.WriteAllBytes(temp, bytes);
        if (File.Exists(_indexPath)) File.Move(temp, _indexPath, overwrite: true);
        else File.Move(temp, _indexPath);
    }

    private JsonObject RecordMetadata(CheckpointRecord record, bool expired, CheckpointManifest? manifest = null)
    {
        var result = new JsonObject
        {
            ["checkpoint_ref"] = record.CheckpointRef,
            ["manifest_hash"] = record.ManifestHash,
            ["repository_relative_path"] = record.RepositoryRelativePath,
            ["head_oid"] = record.HeadOid,
            ["source_state_id"] = record.SourceStateId,
            ["created_epoch_ms"] = record.CreatedEpochMs,
            ["expires_epoch_ms"] = record.ExpiresEpochMs,
            ["expired"] = expired,
            ["entry_count"] = record.EntryCount,
            ["total_bytes"] = record.TotalBytes,
            ["staged_count"] = record.StagedCount,
            ["unstaged_count"] = record.UnstagedCount,
            ["untracked_count"] = record.UntrackedCount,
            ["ignored_count"] = record.IgnoredCount,
            ["excluded_count"] = record.ExcludedCount,
            ["workspace_authority_id"] = record.WorkspaceAuthorityId,
        };
        if (manifest is not null)
        {
            var items = new JsonArray();
            foreach (var entry in manifest.Entries)
            {
                items.Add(new JsonObject
                {
                    ["relative_path"] = entry.RelativePath,
                    ["staged"] = entry.Staged,
                    ["unstaged"] = entry.Unstaged,
                    ["untracked"] = entry.Untracked,
                    ["ignored"] = entry.Ignored,
                    ["generated"] = entry.Generated,
                    ["worktree_exists"] = entry.WorktreeExists,
                    ["index_size_bytes"] = entry.IndexSizeBytes,
                    ["worktree_size_bytes"] = entry.WorktreeSizeBytes,
                    ["index_sha256"] = entry.IndexSha256,
                    ["worktree_sha256"] = entry.WorktreeSha256,
                    ["index_excluded_reason"] = entry.IndexExcludedReason,
                    ["worktree_excluded_reason"] = entry.WorktreeExcludedReason,
                });
            }
            result["entries"] = items;
            result["include_untracked"] = manifest.IncludeUntracked;
            result["include_ignored"] = manifest.IncludeIgnored;
            result["include_generated"] = manifest.IncludeGenerated;
            result["index_fingerprint"] = manifest.IndexFingerprint;
        }
        return result;
    }

    private void EnforcePayloadBounds(string path, long bytes, ref long totalBytes, long maximum)
    {
        if (bytes < 0)
            throw new FileMcpException($"Checkpoint file size is invalid: {path}");
        if (totalBytes > maximum - bytes)
            throw new FileMcpException($"Checkpoint payload exceeds max_total_bytes ({maximum})");
        totalBytes += bytes;
    }

    private static IEnumerable<string> ManifestContentRefs(CheckpointManifest manifest)
    {
        foreach (var entry in manifest.Entries)
        {
            if (!string.IsNullOrEmpty(entry.IndexContentRef)) yield return entry.IndexContentRef;
            if (!string.IsNullOrEmpty(entry.WorktreeContentRef)) yield return entry.WorktreeContentRef;
        }
    }

    private static IReadOnlyList<string> SplitNul(string value) =>
        value.Split('\0', StringSplitOptions.RemoveEmptyEntries)
            .Select(path => path.Replace('\\', '/'))
            .Distinct(StringComparer.Ordinal)
            .ToArray();

    private static bool IsGeneratedPath(string path)
    {
        var generated = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "node_modules", ".venv", "venv", "__pycache__", "build", "dist", "out", "target", ".gradle"
        };
        return path.Replace('\\', '/').Split('/', StringSplitOptions.RemoveEmptyEntries).Any(generated.Contains);
    }

    private static void ValidateRepoRelativePath(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || Path.IsPathRooted(path) || path.Contains('\0'))
            throw new FileMcpException("Checkpoint path is invalid");
        var normalized = path.Replace('\\', '/');
        if (normalized == "." || normalized.StartsWith("../", StringComparison.Ordinal) || normalized.Contains("/../", StringComparison.Ordinal))
            throw new FileMcpException("Checkpoint path escapes the repository");
    }

    private static string RequiredString(JsonObject value, string key) =>
        value[key] is JsonValue node && node.TryGetValue<string>(out var text) && !string.IsNullOrWhiteSpace(text)
            ? text
            : throw new FileMcpException($"Checkpoint SourceStateRef is missing {key}");

    private static string? OptionalString(JsonObject value, string key) =>
        value[key] is JsonValue node && node.TryGetValue<string>(out var text) && !string.IsNullOrWhiteSpace(text)
            ? text
            : null;

    private static void RequireContinue(ToolExecutionContext? context, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (context is not null && !context.TryContinue())
            throw new FileMcpException($"Checkpoint operation aborted: {context.TruncationReason}");
    }

    private TimeSpan ResolveTtl(int seconds)
    {
        var ttl = seconds == 0 ? _options.DefaultTtl : TimeSpan.FromSeconds(seconds);
        if (ttl <= TimeSpan.Zero || ttl > _options.MaxTtl)
            throw new FileMcpException($"ttl_seconds must be between 1 and {(int)_options.MaxTtl.TotalSeconds}");
        return ttl;
    }

    private static void ValidateOptions(WorkspaceCheckpointOptions options)
    {
        if (options.DefaultTtl <= TimeSpan.Zero || options.DefaultTtl > options.MaxTtl)
            throw new FileMcpException("Checkpoint TTL options are invalid");
        if (options.MaxEntries < 1 || options.MaxEntries > 50_000)
            throw new FileMcpException("Checkpoint MaxEntries is invalid");
        if (options.MaxTotalBytes < 1 || options.MaxTotalBytes > 512L * 1024 * 1024)
            throw new FileMcpException("Checkpoint MaxTotalBytes is invalid");
        if (options.MaxSingleFileBytes < 1 || options.MaxSingleFileBytes > options.MaxTotalBytes)
            throw new FileMcpException("Checkpoint MaxSingleFileBytes is invalid");
    }

    private static void ValidateRecord(CheckpointRecord record)
    {
        if (string.IsNullOrWhiteSpace(record.CheckpointRef) || string.IsNullOrWhiteSpace(record.ManifestHash) ||
            string.IsNullOrWhiteSpace(record.WorkspaceAuthorityId) || string.IsNullOrWhiteSpace(record.SourceStateId) ||
            record.CreatedEpochMs <= 0 || record.ExpiresEpochMs <= record.CreatedEpochMs ||
            record.EntryCount < 0 || record.TotalBytes < 0)
            throw new FileMcpException("Checkpoint metadata index is invalid");
    }

    private static void ValidateManifest(CheckpointManifest manifest)
    {
        if (manifest.SchemaVersion != SchemaVersion || string.IsNullOrWhiteSpace(manifest.WorkspaceAuthorityId) ||
            string.IsNullOrWhiteSpace(manifest.SourceStateId) || string.IsNullOrWhiteSpace(manifest.IndexFingerprint) ||
            manifest.CreatedEpochMs <= 0 || manifest.ExpiresEpochMs <= manifest.CreatedEpochMs ||
            manifest.Entries is null || manifest.TotalBytes < 0)
            throw new FileMcpException("Checkpoint manifest is invalid");
    }

    private sealed class CheckpointRecord
    {
        public string CheckpointRef { get; set; } = "";
        public string ManifestHash { get; set; } = "";
        public string WorkspaceAuthorityId { get; set; } = "";
        public string RepositoryRelativePath { get; set; } = "";
        public string? HeadOid { get; set; }
        public string SourceStateId { get; set; } = "";
        public long CreatedEpochMs { get; set; }
        public long ExpiresEpochMs { get; set; }
        public int EntryCount { get; set; }
        public long TotalBytes { get; set; }
        public int StagedCount { get; set; }
        public int UnstagedCount { get; set; }
        public int UntrackedCount { get; set; }
        public int IgnoredCount { get; set; }
        public int ExcludedCount { get; set; }
    }

    private sealed class CheckpointManifest
    {
        public int SchemaVersion { get; set; }
        public string WorkspaceAuthorityId { get; set; } = "";
        public string RepositoryRelativePath { get; set; } = "";
        public string? HeadOid { get; set; }
        public string IndexFingerprint { get; set; } = "";
        public string SourceStateId { get; set; } = "";
        public long CreatedEpochMs { get; set; }
        public long ExpiresEpochMs { get; set; }
        public bool IncludeUntracked { get; set; }
        public bool IncludeIgnored { get; set; }
        public bool IncludeGenerated { get; set; }
        public int StagedCount { get; set; }
        public int UnstagedCount { get; set; }
        public int UntrackedCount { get; set; }
        public int IgnoredCount { get; set; }
        public int ExcludedCount { get; set; }
        public long TotalBytes { get; set; }
        public List<CheckpointManifestEntry> Entries { get; set; } = [];
    }

    private sealed class CheckpointManifestEntry
    {
        public string RelativePath { get; set; } = "";
        public bool Staged { get; set; }
        public bool Unstaged { get; set; }
        public bool Untracked { get; set; }
        public bool Ignored { get; set; }
        public bool Generated { get; set; }
        public bool WorktreeExists { get; set; }
        public string? IndexContentRef { get; set; }
        public string? IndexSha256 { get; set; }
        public long IndexSizeBytes { get; set; }
        public string? IndexExcludedReason { get; set; }
        public string? WorktreeContentRef { get; set; }
        public string? WorktreeSha256 { get; set; }
        public long WorktreeSizeBytes { get; set; }
        public string? WorktreeExcludedReason { get; set; }
    }
}
