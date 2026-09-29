using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed class QuarantineServiceOptions
{
    public string? MetadataRootDirectory { get; init; }
    public TimeSpan DefaultTtl { get; init; } = TimeSpan.FromHours(24);
    public TimeSpan MaxTtl { get; init; } = TimeSpan.FromDays(7);
    public int MaxTreeEntries { get; init; } = 10_000;
    public long MaxTreeBytes { get; init; } = 512L * 1024 * 1024;
    public Func<DateTimeOffset> UtcNow { get; init; } = () => DateTimeOffset.UtcNow;
    internal Func<string, Exception?>? FaultInjector { get; init; }
}

internal sealed class QuarantineService
{
    private const int SchemaVersion = 1;
    private const int MaxSingleFileBytes = 64 * 1024 * 1024;
    private readonly SafePathResolver _resolver;
    private readonly FileVersionService _versions;
    private readonly AuthorizedPathSnapshotService _mutationGuard;
    private readonly Func<ArtifactContentStore> _artifactFactory;
    private readonly ServerPolicy _policy;
    private readonly QuarantineServiceOptions _options;
    private readonly string _workspaceAuthorityId;
    private readonly string _metadataRoot;
    private readonly string _indexPath;
    private readonly Action<string>? _stageForTests;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly JsonSerializerOptions _json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };

    private bool _initialized;
    private List<QuarantineRecord> _records = [];

    public QuarantineService(
        SafePathResolver resolver,
        FileVersionService versions,
        AuthorizedPathSnapshotService mutationGuard,
        ArtifactContentStore artifacts,
        ServerPolicy policy,
        QuarantineServiceOptions? options = null,
        Action<string>? stageForTests = null)
        : this(resolver, versions, mutationGuard, () => artifacts, policy, options, stageForTests)
    {
    }

    internal QuarantineService(
        SafePathResolver resolver,
        FileVersionService versions,
        AuthorizedPathSnapshotService mutationGuard,
        Func<ArtifactContentStore> artifactFactory,
        ServerPolicy policy,
        QuarantineServiceOptions? options = null,
        Action<string>? stageForTests = null)
    {
        _resolver = resolver;
        _versions = versions;
        _mutationGuard = mutationGuard;
        _artifactFactory = artifactFactory ?? throw new ArgumentNullException(nameof(artifactFactory));
        _policy = policy;
        _options = options ?? new QuarantineServiceOptions();
        _stageForTests = stageForTests;
        ValidateOptions(_options);
        _workspaceAuthorityId = ArtifactContentStore.WorkspaceAuthorityId(_resolver.Root);
        var baseRoot = _options.MetadataRootDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FileMCP",
            "quarantine-v1");
        _metadataRoot = Path.Combine(
            Path.GetFullPath(baseRoot),
            _workspaceAuthorityId["sha256:".Length..]);
        _indexPath = Path.Combine(_metadataRoot, "index-v1.json");
    }

    internal string MetadataRootForTest => _metadataRoot;
    internal string IndexPathForTest => _indexPath;
    private ArtifactContentStore Artifacts => _artifactFactory();

    public async Task<JsonObject> DeleteAsync(
        string relativePath,
        string expectedVersion,
        bool dryRun,
        int ttlSeconds,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        RequireContinue(context, cancellationToken);
        var target = _resolver.ResolveForDeletion(relativePath);
        if (PathEquals(target, _resolver.Root))
            throw new FileMcpException("Refusing to quarantine-delete the shared root directory");

        var attributes = _resolver.GetAttributesWithoutFollowingFinalTarget(target, $"No such path: {relativePath}");
        if ((attributes & FileAttributes.ReparsePoint) != 0)
            throw new FileMcpException("quarantine_delete does not accept symlinks or reparse-point targets");
        var isTree = (attributes & FileAttributes.Directory) != 0;

        var ttl = ResolveTtl(ttlSeconds);
        if (isTree)
        {
            var preview = CaptureTree(relativePath, target, context, cancellationToken);
            if (dryRun)
                return DeletePreview(relativePath, preview.SourceVersion, isTree: true, preview.Entries.Count, preview.TotalBytes, ttl);

            var normalizedExpected = RequireExpectedVersion(expectedVersion);
            if (!string.Equals(preview.SourceVersion, normalizedExpected, StringComparison.Ordinal))
                throw new FileMcpException("Directory tree changed since the expected quarantine version was captured");
            var guard = _mutationGuard.CaptureExisting(relativePath);
            return await DeleteTreeAsync(relativePath, target, preview, guard, ttl, preparedPolicy, context, cancellationToken).ConfigureAwait(false);
        }

        var read = _versions.ReadVersioned(relativePath, MaxSingleFileBytes);
        if (dryRun)
            return DeletePreview(relativePath, read.VersionToken, isTree: false, 1, read.SizeBytes, ttl);

        var fileExpected = RequireExpectedVersion(expectedVersion);
        var expectedRead = _versions.ReadExpectedVersioned(relativePath, fileExpected, MaxSingleFileBytes);
        var fileGuard = _mutationGuard.CaptureExisting(relativePath);
        return await DeleteFileAsync(relativePath, target, expectedRead, fileGuard, ttl, preparedPolicy, context, cancellationToken).ConfigureAwait(false);
    }

    public async Task<JsonObject> ListAsync(int maxItems, CancellationToken cancellationToken)
    {
        if (maxItems < 1 || maxItems > 1000)
            throw new FileMcpException("max_items must be between 1 and 1000");
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var now = _options.UtcNow().ToUnixTimeMilliseconds();
            var items = new JsonArray();
            foreach (var record in _records
                         .Where(r => r.WorkspaceAuthorityId == _workspaceAuthorityId)
                         .OrderByDescending(r => r.CreatedEpochMs)
                         .Take(maxItems))
            {
                items.Add(RecordMetadata(record, expired: record.ExpiresEpochMs <= now));
            }
            return new JsonObject
            {
                ["items"] = items,
                ["count"] = items.Count,
                ["workspace_authority_id"] = _workspaceAuthorityId,
            };
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<JsonObject> GetAsync(string quarantineRef, CancellationToken cancellationToken)
    {
        var loaded = await LoadRecordAndManifestAsync(quarantineRef, cancellationToken).ConfigureAwait(false);
        return RecordMetadata(loaded.Record, expired: false, loaded.Manifest);
    }

    public async Task<JsonObject> RestoreAsync(
        string quarantineRef,
        string targetRelativePath,
        bool replaceExisting,
        string expectedTargetVersion,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        RequireContinue(context, cancellationToken);
        var loaded = await LoadRecordAndManifestAsync(quarantineRef, cancellationToken).ConfigureAwait(false);
        var record = loaded.Record;
        var manifest = loaded.Manifest;
        if (record.State == "restored")
            throw new FileMcpException("Quarantine item was already restored");

        var targetRelative = string.IsNullOrWhiteSpace(targetRelativePath)
            ? manifest.OriginalRelativePath
            : targetRelativePath.Trim();
        if (manifest.IsTree)
        {
            if (replaceExisting)
                throw new FileMcpException("Tree restore requires an absent destination; replace_existing is not supported for directory trees");
            return await RestoreTreeAsync(record, manifest, targetRelative, preparedPolicy, context, cancellationToken).ConfigureAwait(false);
        }

        return await RestoreFileAsync(
            record,
            manifest,
            targetRelative,
            replaceExisting,
            expectedTargetVersion,
            preparedPolicy,
            context,
            cancellationToken).ConfigureAwait(false);
    }

    private async Task<JsonObject> DeleteFileAsync(
        string relativePath,
        string target,
        FileVersionedRead source,
        AuthorizedPathSnapshot guard,
        TimeSpan ttl,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        var createdRefs = new List<string>();
        QuarantineRecord? record = null;
        var sourceDeleted = false;
        var deleteCommitStarted = false;
        try
        {
            RequireContinue(context, cancellationToken);
            await using var sourceStream = new MemoryStream(source.Data, writable: false);
            var payload = await Artifacts.PutAsync(
                sourceStream,
                _workspaceAuthorityId,
                ArtifactContentClasses.Quarantine,
                "application/octet-stream",
                ttl,
                cancellationToken: cancellationToken).ConfigureAwait(false);
            createdRefs.Add(payload.ContentRef);
            if (!string.Equals(payload.BlobId, source.ContentHash, StringComparison.Ordinal))
                throw new FileMcpException("Quarantine payload digest does not match the strong source version");

            var manifest = new QuarantineManifest
            {
                SchemaVersion = SchemaVersion,
                OriginalRelativePath = relativePath,
                SourceVersion = source.VersionToken,
                IsTree = false,
                CreatedEpochMs = _options.UtcNow().ToUnixTimeMilliseconds(),
                ExpiresEpochMs = _options.UtcNow().Add(ttl).ToUnixTimeMilliseconds(),
                Entries =
                [
                    new QuarantineManifestEntry
                    {
                        RelativePath = "",
                        EntryType = "file",
                        SizeBytes = source.SizeBytes,
                        Sha256 = source.ContentHash,
                        ContentRef = payload.ContentRef,
                    },
                ],
            };
            var packaged = await StoreManifestAsync(manifest, ttl, createdRefs, cancellationToken).ConfigureAwait(false);
            record = NewRecord(packaged, manifest);
            await AddRecordAsync(record, cancellationToken).ConfigureAwait(false);
            await VerifyPackageAsync(record, manifest, cancellationToken).ConfigureAwait(false);

            InvokeStage("after_package_verified");
            _policy.Authorize("quarantine_delete", preparedPolicy);
            _ = _mutationGuard.Verify(guard);
            _ = _versions.VerifyExpectedVersion(relativePath, source.VersionToken, MaxSingleFileBytes);
            RequireContinue(context, cancellationToken);
            deleteCommitStarted = true;
            File.Delete(target);
            sourceDeleted = true;
            record.State = "quarantined";
            try
            {
                await ReplaceRecordAsync(record, cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                record.State = "prepared";
                throw;
            }
            return DeleteResult(record, manifest);
        }
        catch
        {
            if (!sourceDeleted && !deleteCommitStarted)
            {
                if (record is not null) await RemoveRecordBestEffortAsync(record.QuarantineRef).ConfigureAwait(false);
                await DeleteRefsBestEffortAsync(createdRefs).ConfigureAwait(false);
            }
            throw;
        }
    }

    private async Task<JsonObject> DeleteTreeAsync(
        string relativePath,
        string target,
        TreeSnapshot snapshot,
        AuthorizedPathSnapshot guard,
        TimeSpan ttl,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        var createdRefs = new List<string>();
        QuarantineRecord? record = null;
        var sourceDeleted = false;
        var deleteCommitStarted = false;
        try
        {
            var manifestEntries = new List<QuarantineManifestEntry>();
            foreach (var entry in snapshot.Entries)
            {
                RequireContinue(context, cancellationToken);
                if (entry.EntryType == "directory")
                {
                    manifestEntries.Add(new QuarantineManifestEntry
                    {
                        RelativePath = entry.RelativePath,
                        EntryType = "directory",
                        SizeBytes = 0,
                        Sha256 = "",
                    });
                    continue;
                }

                await using var stream = new FileStream(
                    entry.AbsolutePath,
                    FileMode.Open,
                    FileAccess.Read,
                    FileShare.ReadWrite | FileShare.Delete,
                    128 * 1024,
                    FileOptions.Asynchronous | FileOptions.SequentialScan);
                var payload = await Artifacts.PutAsync(
                    stream,
                    _workspaceAuthorityId,
                    ArtifactContentClasses.Quarantine,
                    "application/octet-stream",
                    ttl,
                    cancellationToken: cancellationToken).ConfigureAwait(false);
                createdRefs.Add(payload.ContentRef);
                if (!string.Equals(payload.BlobId, entry.Sha256, StringComparison.Ordinal))
                    throw new FileMcpException($"Quarantine package detected a changed tree file: {entry.RelativePath}");
                manifestEntries.Add(new QuarantineManifestEntry
                {
                    RelativePath = entry.RelativePath,
                    EntryType = "file",
                    SizeBytes = entry.SizeBytes,
                    Sha256 = entry.Sha256,
                    ContentRef = payload.ContentRef,
                });
            }

            var finalSnapshot = CaptureTree(relativePath, target, context, cancellationToken);
            if (!string.Equals(finalSnapshot.SourceVersion, snapshot.SourceVersion, StringComparison.Ordinal))
                throw new FileMcpException("Directory tree changed while the quarantine package was being captured");

            var manifest = new QuarantineManifest
            {
                SchemaVersion = SchemaVersion,
                OriginalRelativePath = relativePath,
                SourceVersion = snapshot.SourceVersion,
                IsTree = true,
                CreatedEpochMs = _options.UtcNow().ToUnixTimeMilliseconds(),
                ExpiresEpochMs = _options.UtcNow().Add(ttl).ToUnixTimeMilliseconds(),
                Entries = manifestEntries,
            };
            var packaged = await StoreManifestAsync(manifest, ttl, createdRefs, cancellationToken).ConfigureAwait(false);
            record = NewRecord(packaged, manifest);
            await AddRecordAsync(record, cancellationToken).ConfigureAwait(false);
            await VerifyPackageAsync(record, manifest, cancellationToken).ConfigureAwait(false);

            InvokeStage("after_package_verified");
            _policy.Authorize("quarantine_delete", preparedPolicy);
            _ = _mutationGuard.Verify(guard);
            var commitSnapshot = CaptureTree(relativePath, target, context, cancellationToken);
            if (!string.Equals(commitSnapshot.SourceVersion, snapshot.SourceVersion, StringComparison.Ordinal))
                throw new FileMcpException("Directory tree changed before quarantine deletion could commit");
            RequireContinue(context, cancellationToken);
            deleteCommitStarted = true;
            Directory.Delete(target, recursive: true);
            sourceDeleted = true;
            record.State = "quarantined";
            try
            {
                await ReplaceRecordAsync(record, cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                record.State = "prepared";
                throw;
            }
            return DeleteResult(record, manifest);
        }
        catch
        {
            if (!sourceDeleted && !deleteCommitStarted)
            {
                if (record is not null) await RemoveRecordBestEffortAsync(record.QuarantineRef).ConfigureAwait(false);
                await DeleteRefsBestEffortAsync(createdRefs).ConfigureAwait(false);
            }
            throw;
        }
    }

    private async Task<JsonObject> RestoreFileAsync(
        QuarantineRecord record,
        QuarantineManifest manifest,
        string targetRelative,
        bool replaceExisting,
        string expectedTargetVersion,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        var entry = manifest.Entries.SingleOrDefault()
            ?? throw new FileMcpException("Quarantine file manifest is invalid");
        if (entry.EntryType != "file" || string.IsNullOrWhiteSpace(entry.ContentRef))
            throw new FileMcpException("Quarantine file manifest is invalid");

        var target = _resolver.Resolve(targetRelative);
        var exists = EntryExists(target);
        AuthorizedPathSnapshot guard;
        string? normalizedTargetVersion = null;
        if (exists)
        {
            if (!replaceExisting)
                throw new FileMcpException("Restore destination already exists; replace_existing must be explicit");
            normalizedTargetVersion = RequireExpectedVersion(expectedTargetVersion);
            _ = _versions.VerifyExpectedVersion(targetRelative, normalizedTargetVersion, MaxSingleFileBytes);
            guard = _mutationGuard.CaptureExisting(targetRelative);
        }
        else
        {
            if (replaceExisting)
                throw new FileMcpException("replace_existing requested but restore destination is absent");
            guard = _mutationGuard.CaptureNewTarget(targetRelative);
        }

        InvokeStage("after_restore_plan");
        var parent = Path.GetDirectoryName(target)
            ?? throw new FileMcpException("Restore destination parent is unavailable");
        if (!Directory.Exists(parent))
            throw new FileMcpException("Restore destination parent must already exist");

        var temp = target + ".filemcp-restore-" + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            await using (var output = new FileStream(
                             temp,
                             FileMode.CreateNew,
                             FileAccess.Write,
                             FileShare.None,
                             128 * 1024,
                             FileOptions.Asynchronous | FileOptions.WriteThrough))
            {
                await Artifacts.CopyToAsync(
                    entry.ContentRef!,
                    _workspaceAuthorityId,
                    value => value == ArtifactContentClasses.Quarantine,
                    output,
                    cancellationToken).ConfigureAwait(false);
                await output.FlushAsync(cancellationToken).ConfigureAwait(false);
                output.Flush(flushToDisk: true);
            }
            VerifyRestoredFile(temp, entry);

            _policy.Authorize("quarantine_restore", preparedPolicy);
            _ = _mutationGuard.Verify(guard);
            if (normalizedTargetVersion is not null)
                _ = _versions.VerifyExpectedVersion(targetRelative, normalizedTargetVersion, MaxSingleFileBytes);
            RequireContinue(context, cancellationToken);
            File.Move(temp, target, overwrite: exists);

            VerifyRestoredFile(target, entry);
            record.State = "restored";
            record.LastRestoreTarget = targetRelative;
            record.RecoveryContentRef = null;
            await ReplaceRecordAsync(record, cancellationToken).ConfigureAwait(false);
            return RestoreResult(record, "restored", targetRelative, recoveryRef: null);
        }
        finally
        {
            try { File.Delete(temp); } catch { }
        }
    }

    private async Task<JsonObject> RestoreTreeAsync(
        QuarantineRecord record,
        QuarantineManifest manifest,
        string targetRelative,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        var target = _resolver.Resolve(targetRelative);
        if (EntryExists(target))
            throw new FileMcpException("Tree restore destination must be absent");

        var rootGuard = _mutationGuard.CaptureNewTarget(targetRelative);
        InvokeStage("after_restore_plan");
        var rollback = await CreateRollbackCheckpointAsync(record, manifest, targetRelative, cancellationToken).ConfigureAwait(false);
        record.RecoveryContentRef = rollback.ContentRef;
        await ReplaceRecordAsync(record, cancellationToken).ConfigureAwait(false);

        AuthorizedPathSnapshot? createdRootGuard = null;
        try
        {
            _policy.Authorize("quarantine_restore", preparedPolicy);
            _ = _mutationGuard.Verify(rootGuard);
            RequireContinue(context, cancellationToken);
            Directory.CreateDirectory(target);
            createdRootGuard = _mutationGuard.CaptureExisting(targetRelative);

            foreach (var directory in manifest.Entries
                         .Where(e => e.EntryType == "directory")
                         .OrderBy(e => PathDepth(e.RelativePath))
                         .ThenBy(e => e.RelativePath, StringComparer.Ordinal))
            {
                RequireContinue(context, cancellationToken);
                var relativeChild = JoinRelative(targetRelative, directory.RelativePath);
                var child = _resolver.Resolve(relativeChild);
                if (EntryExists(child))
                    throw new FileMcpException($"Tree restore destination appeared unexpectedly: {relativeChild}");
                Directory.CreateDirectory(child);
            }

            foreach (var file in manifest.Entries
                         .Where(e => e.EntryType == "file")
                         .OrderBy(e => e.RelativePath, StringComparer.Ordinal))
            {
                RequireContinue(context, cancellationToken);
                var relativeChild = JoinRelative(targetRelative, file.RelativePath);
                var child = _resolver.Resolve(relativeChild);
                var childGuard = _mutationGuard.CaptureNewTarget(relativeChild);
                var parent = Path.GetDirectoryName(child)
                    ?? throw new FileMcpException("Tree restore child parent is unavailable");
                Directory.CreateDirectory(parent);
                var temp = child + ".filemcp-restore-" + Guid.NewGuid().ToString("N") + ".tmp";
                try
                {
                    await using (var output = new FileStream(
                                     temp,
                                     FileMode.CreateNew,
                                     FileAccess.Write,
                                     FileShare.None,
                                     128 * 1024,
                                     FileOptions.Asynchronous | FileOptions.WriteThrough))
                    {
                        await Artifacts.CopyToAsync(
                            file.ContentRef ?? throw new FileMcpException("Tree manifest file payload is missing"),
                            _workspaceAuthorityId,
                            value => value == ArtifactContentClasses.Quarantine,
                            output,
                            cancellationToken).ConfigureAwait(false);
                        await output.FlushAsync(cancellationToken).ConfigureAwait(false);
                        output.Flush(flushToDisk: true);
                    }
                    VerifyRestoredFile(temp, file);
                    _policy.Authorize("quarantine_restore", preparedPolicy);
                    _ = _mutationGuard.Verify(childGuard);
                    RequireContinue(context, cancellationToken);
                    File.Move(temp, child, overwrite: false);
                    VerifyRestoredFile(child, file);
                    InvokeStage("after_tree_publish:" + file.RelativePath);
                }
                finally
                {
                    try { File.Delete(temp); } catch { }
                }
            }

            VerifyRestoredTree(targetRelative, target, manifest, context, cancellationToken);
            await Artifacts.DeleteAsync(
                rollback.ContentRef,
                _workspaceAuthorityId,
                value => value == ArtifactContentClasses.Checkpoint,
                cancellationToken).ConfigureAwait(false);
            record.RecoveryContentRef = null;
            record.State = "restored";
            record.LastRestoreTarget = targetRelative;
            await ReplaceRecordAsync(record, cancellationToken).ConfigureAwait(false);
            return RestoreResult(record, "restored", targetRelative, recoveryRef: null);
        }
        catch (Exception restoreFailure)
        {
            try
            {
                InvokeStage("before_tree_rollback");
                if (createdRootGuard is not null)
                {
                    _ = _mutationGuard.Verify(createdRootGuard);
                    if (Directory.Exists(target))
                        Directory.Delete(target, recursive: true);
                    if (EntryExists(target))
                        throw new FileMcpException("Tree rollback could not remove the partially restored destination");
                }

                await Artifacts.DeleteAsync(
                    rollback.ContentRef,
                    _workspaceAuthorityId,
                    value => value == ArtifactContentClasses.Checkpoint,
                    cancellationToken).ConfigureAwait(false);
                record.RecoveryContentRef = null;
                record.State = "rolled_back";
                record.LastRestoreTarget = targetRelative;
                await ReplaceRecordAsync(record, CancellationToken.None).ConfigureAwait(false);
                return RestoreResult(record, "rolled_back", targetRelative, recoveryRef: null, error: restoreFailure.Message);
            }
            catch (Exception rollbackFailure)
            {
                record.State = "partial_recovery_required";
                record.LastRestoreTarget = targetRelative;
                record.RecoveryContentRef = rollback.ContentRef;
                await ReplaceRecordBestEffortAsync(record).ConfigureAwait(false);
                return RestoreResult(
                    record,
                    "partial_recovery_required",
                    targetRelative,
                    rollback.ContentRef,
                    error: restoreFailure.Message,
                    rollbackError: rollbackFailure.Message);
            }
        }
    }

    private TreeSnapshot CaptureTree(
        string originalRelativePath,
        string rootPath,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        var rootAttributes = _resolver.GetAttributesWithoutFollowingFinalTarget(rootPath, $"No such directory: {originalRelativePath}");
        if ((rootAttributes & FileAttributes.Directory) == 0 || (rootAttributes & FileAttributes.ReparsePoint) != 0)
            throw new FileMcpException("Quarantine tree source must be a real directory, not a symlink/reparse point");

        var entries = new List<TreeEntry>();
        long totalBytes = 0;
        var pending = new Stack<(string Absolute, string Relative)>();
        pending.Push((rootPath, ""));
        while (pending.Count > 0)
        {
            RequireContinue(context, cancellationToken);
            var current = pending.Pop();
            foreach (var child in Directory.EnumerateFileSystemEntries(current.Absolute).OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
            {
                RequireContinue(context, cancellationToken);
                if (context is not null && !context.TryVisitEntry())
                    throw new FileMcpException($"Quarantine tree budget exhausted: {context.TruncationReason}");
                if (entries.Count >= _options.MaxTreeEntries)
                    throw new FileMcpException($"Quarantine tree exceeds the {_options.MaxTreeEntries} entry limit");
                var attributes = _resolver.GetAttributesWithoutFollowingFinalTarget(child, "Quarantine tree entry disappeared");
                if ((attributes & FileAttributes.ReparsePoint) != 0)
                    throw new FileMcpException("Quarantine tree refuses symlink/reparse-point descendants");
                var name = Path.GetFileName(child);
                var rel = string.IsNullOrEmpty(current.Relative)
                    ? name
                    : current.Relative.Replace('\\', '/') + "/" + name;
                if ((attributes & FileAttributes.Directory) != 0)
                {
                    entries.Add(new TreeEntry(rel.Replace('\\', '/'), child, "directory", 0, ""));
                    pending.Push((child, rel));
                    continue;
                }

                var info = new FileInfo(child);
                var size = info.Length;
                if (context is not null && !context.TryScanFile(size))
                    throw new FileMcpException($"Quarantine tree budget exhausted: {context.TruncationReason}");
                totalBytes = checked(totalBytes + size);
                if (totalBytes > _options.MaxTreeBytes)
                    throw new FileMcpException("Quarantine tree exceeds the configured total-byte limit");
                if (size > MaxSingleFileBytes)
                    throw new FileMcpException($"Quarantine tree file exceeds the {MaxSingleFileBytes} byte per-file limit: {rel}");
                var hash = HashFile(child, context, cancellationToken);
                entries.Add(new TreeEntry(rel.Replace('\\', '/'), child, "file", size, hash));
            }
        }

        entries = entries
            .OrderBy(e => e.RelativePath, StringComparer.Ordinal)
            .ThenBy(e => e.EntryType, StringComparer.Ordinal)
            .ToList();
        var canonical = new StringBuilder();
        canonical.Append("path=").Append(originalRelativePath.Replace('\\', '/')).Append('\n');
        foreach (var entry in entries)
            canonical.Append(entry.EntryType).Append('|')
                .Append(entry.RelativePath).Append('|')
                .Append(entry.SizeBytes).Append('|')
                .Append(entry.Sha256).Append('\n');
        var version = "tree-" + Sha256Tagged(Encoding.UTF8.GetBytes(canonical.ToString()));
        return new TreeSnapshot(version, entries, totalBytes);
    }

    private string HashFile(string path, ToolExecutionContext? context, CancellationToken cancellationToken)
    {
        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 128 * 1024, FileOptions.SequentialScan);
        var buffer = new byte[128 * 1024];
        while (true)
        {
            RequireContinue(context, cancellationToken);
            var read = stream.Read(buffer, 0, buffer.Length);
            if (read == 0) break;
            hash.AppendData(buffer, 0, read);
        }
        return "sha256:" + Convert.ToHexString(hash.GetHashAndReset()).ToLowerInvariant();
    }

    private async Task<(ArtifactContentDescriptor Descriptor, string ManifestHash)> StoreManifestAsync(
        QuarantineManifest manifest,
        TimeSpan ttl,
        List<string> createdRefs,
        CancellationToken cancellationToken)
    {
        var bytes = JsonSerializer.SerializeToUtf8Bytes(manifest, _json);
        var hash = Sha256Tagged(bytes);
        await using var input = new MemoryStream(bytes, writable: false);
        var descriptor = await Artifacts.PutAsync(
            input,
            _workspaceAuthorityId,
            ArtifactContentClasses.Quarantine,
            "application/vnd.filemcp.quarantine-manifest+json",
            ttl,
            cancellationToken: cancellationToken).ConfigureAwait(false);
        createdRefs.Add(descriptor.ContentRef);
        if (!string.Equals(descriptor.BlobId, hash, StringComparison.Ordinal))
            throw new FileMcpException("Quarantine manifest digest mismatch");
        return (descriptor, hash);
    }

    private QuarantineRecord NewRecord(
        (ArtifactContentDescriptor Descriptor, string ManifestHash) packaged,
        QuarantineManifest manifest) =>
        new()
        {
            QuarantineRef = packaged.Descriptor.ContentRef,
            WorkspaceAuthorityId = _workspaceAuthorityId,
            OriginalRelativePath = manifest.OriginalRelativePath,
            SourceVersion = manifest.SourceVersion,
            ManifestHash = packaged.ManifestHash,
            IsTree = manifest.IsTree,
            CreatedEpochMs = packaged.Descriptor.CreatedEpochMs,
            ExpiresEpochMs = packaged.Descriptor.ExpiresEpochMs,
            State = "prepared",
        };

    private async Task VerifyPackageAsync(QuarantineRecord record, QuarantineManifest manifest, CancellationToken cancellationToken)
    {
        var descriptor = await Artifacts.ResolveAsync(
            record.QuarantineRef,
            _workspaceAuthorityId,
            value => value == ArtifactContentClasses.Quarantine,
            cancellationToken).ConfigureAwait(false);
        if (!string.Equals(descriptor.BlobId, record.ManifestHash, StringComparison.Ordinal))
            throw new FileMcpException("Quarantine manifest blob does not match recorded manifest hash");

        foreach (var entry in manifest.Entries.Where(e => e.EntryType == "file"))
        {
            var contentRef = entry.ContentRef ?? throw new FileMcpException("Quarantine manifest file payload is missing");
            var payload = await Artifacts.ResolveAsync(
                contentRef,
                _workspaceAuthorityId,
                value => value == ArtifactContentClasses.Quarantine,
                cancellationToken).ConfigureAwait(false);
            if (!string.Equals(payload.BlobId, entry.Sha256, StringComparison.Ordinal) || payload.SizeBytes != entry.SizeBytes)
                throw new FileMcpException($"Quarantine payload verification failed: {entry.RelativePath}");
        }
    }

    private async Task<(QuarantineRecord Record, QuarantineManifest Manifest)> LoadRecordAndManifestAsync(
        string quarantineRef,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(quarantineRef))
            throw new FileMcpException("quarantine_ref is required");
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        QuarantineRecord record;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            record = _records.SingleOrDefault(r =>
                         r.WorkspaceAuthorityId == _workspaceAuthorityId &&
                         string.Equals(r.QuarantineRef, quarantineRef, StringComparison.Ordinal))
                     ?? throw new FileMcpException("QuarantineRef is unavailable");
        }
        finally
        {
            _gate.Release();
        }

        if (record.ExpiresEpochMs <= _options.UtcNow().ToUnixTimeMilliseconds())
            throw new FileMcpException("QuarantineRef expired");

        var descriptor = await Artifacts.ResolveAsync(
            quarantineRef,
            _workspaceAuthorityId,
            value => value == ArtifactContentClasses.Quarantine,
            cancellationToken).ConfigureAwait(false);
        if (!string.Equals(descriptor.BlobId, record.ManifestHash, StringComparison.Ordinal))
            throw new FileMcpException("QuarantineRef metadata does not match its authenticated manifest");

        await using var buffer = new MemoryStream();
        await Artifacts.CopyToAsync(
            quarantineRef,
            _workspaceAuthorityId,
            value => value == ArtifactContentClasses.Quarantine,
            buffer,
            cancellationToken).ConfigureAwait(false);
        var bytes = buffer.ToArray();
        if (!string.Equals(Sha256Tagged(bytes), record.ManifestHash, StringComparison.Ordinal))
            throw new FileMcpException("Quarantine manifest content is corrupt");
        var manifest = JsonSerializer.Deserialize<QuarantineManifest>(bytes, _json)
            ?? throw new FileMcpException("Quarantine manifest is unavailable");
        ValidateManifest(manifest);
        if (!string.Equals(manifest.OriginalRelativePath, record.OriginalRelativePath, StringComparison.Ordinal) ||
            !string.Equals(manifest.SourceVersion, record.SourceVersion, StringComparison.Ordinal) ||
            manifest.IsTree != record.IsTree)
            throw new FileMcpException("Quarantine metadata/manifest mismatch");
        return (record, manifest);
    }

    private async Task<ArtifactContentDescriptor> CreateRollbackCheckpointAsync(
        QuarantineRecord record,
        QuarantineManifest manifest,
        string targetRelative,
        CancellationToken cancellationToken)
    {
        var checkpoint = new JsonObject
        {
            ["schema_version"] = 1,
            ["kind"] = "quarantine-tree-rollback",
            ["target_relative_path"] = targetRelative,
            ["target_expected_absent"] = true,
            ["quarantine_ref"] = record.QuarantineRef,
            ["manifest_hash"] = record.ManifestHash,
            ["created_epoch_ms"] = _options.UtcNow().ToUnixTimeMilliseconds(),
        };
        var bytes = Encoding.UTF8.GetBytes(checkpoint.ToJsonString());
        await using var input = new MemoryStream(bytes, writable: false);
        return await Artifacts.PutAsync(
            input,
            _workspaceAuthorityId,
            ArtifactContentClasses.Checkpoint,
            "application/vnd.filemcp.rollback-checkpoint+json",
            TimeSpan.FromHours(24),
            cancellationToken: cancellationToken).ConfigureAwait(false);
    }

    private void VerifyRestoredTree(
        string targetRelative,
        string target,
        QuarantineManifest manifest,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        var captured = CaptureTree(targetRelative, target, context, cancellationToken);
        var expectedCanonical = new StringBuilder();
        expectedCanonical.Append("path=").Append(targetRelative.Replace('\\', '/')).Append('\n');
        foreach (var entry in manifest.Entries.OrderBy(e => e.RelativePath, StringComparer.Ordinal).ThenBy(e => e.EntryType, StringComparer.Ordinal))
            expectedCanonical.Append(entry.EntryType).Append('|')
                .Append(entry.RelativePath).Append('|')
                .Append(entry.SizeBytes).Append('|')
                .Append(entry.Sha256).Append('\n');
        var expectedVersion = "tree-" + Sha256Tagged(Encoding.UTF8.GetBytes(expectedCanonical.ToString()));
        if (!string.Equals(captured.SourceVersion, expectedVersion, StringComparison.Ordinal))
            throw new FileMcpException("Restored tree failed final manifest verification");
    }

    private static void VerifyRestoredFile(string path, QuarantineManifestEntry entry)
    {
        var info = new FileInfo(path);
        if (!info.Exists || info.Length != entry.SizeBytes)
            throw new FileMcpException("Restored file failed size verification");
        using var stream = File.OpenRead(path);
        var hash = "sha256:" + Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
        if (!string.Equals(hash, entry.Sha256, StringComparison.Ordinal))
            throw new FileMcpException("Restored file failed digest verification");
    }

    private async Task InitializeAsync(CancellationToken cancellationToken)
    {
        if (_initialized) return;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_initialized) return;
            HardenDirectory(_metadataRoot);
            if (File.Exists(_indexPath))
            {
                try
                {
                    var snapshot = JsonSerializer.Deserialize<QuarantineIndex>(
                        await File.ReadAllBytesAsync(_indexPath, cancellationToken).ConfigureAwait(false),
                        _json) ?? throw new FileMcpException("Quarantine metadata index is unavailable");
                    if (snapshot.SchemaVersion != SchemaVersion)
                        throw new FileMcpException("Unsupported quarantine metadata schema version");
                    _records = snapshot.Records;
                    foreach (var record in _records) ValidateRecord(record);
                }
                catch (JsonException ex)
                {
                    throw new FileMcpException($"Quarantine metadata index is corrupt: {ex.Message}");
                }
            }
            _initialized = true;
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task AddRecordAsync(QuarantineRecord record, CancellationToken cancellationToken)
    {
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_records.Any(r => string.Equals(r.QuarantineRef, record.QuarantineRef, StringComparison.Ordinal)))
                throw new FileMcpException("Duplicate quarantine reference");
            var candidate = _records.ToList();
            candidate.Add(record);
            Persist(candidate);
            _records = candidate;
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task ReplaceRecordAsync(QuarantineRecord record, CancellationToken cancellationToken)
    {
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var index = _records.FindIndex(r => string.Equals(r.QuarantineRef, record.QuarantineRef, StringComparison.Ordinal));
            if (index < 0) throw new FileMcpException("QuarantineRef is unavailable");
            var candidate = _records.ToList();
            candidate[index] = record;
            Persist(candidate);
            _records = candidate;
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task ReplaceRecordBestEffortAsync(QuarantineRecord record)
    {
        try { await ReplaceRecordAsync(record, CancellationToken.None).ConfigureAwait(false); } catch { }
    }

    private async Task RemoveRecordBestEffortAsync(string quarantineRef)
    {
        try
        {
            await InitializeAsync(CancellationToken.None).ConfigureAwait(false);
            await _gate.WaitAsync().ConfigureAwait(false);
            try
            {
                var candidate = _records.Where(r => !string.Equals(r.QuarantineRef, quarantineRef, StringComparison.Ordinal)).ToList();
                Persist(candidate);
                _records = candidate;
            }
            finally
            {
                _gate.Release();
            }
        }
        catch { }
    }

    private void Persist(List<QuarantineRecord> records)
    {
        ThrowInjected("before-index-commit");
        var bytes = JsonSerializer.SerializeToUtf8Bytes(
            new QuarantineIndex { SchemaVersion = SchemaVersion, Records = records },
            _json);
        var temp = Path.Combine(_metadataRoot, ".tmp_" + Guid.NewGuid().ToString("N"));
        try
        {
            using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None, 64 * 1024, FileOptions.WriteThrough))
            {
                stream.Write(bytes);
                stream.Flush(flushToDisk: true);
            }
            File.Move(temp, _indexPath, overwrite: true);
        }
        finally
        {
            try { File.Delete(temp); } catch { }
        }
    }

    private async Task DeleteRefsBestEffortAsync(IEnumerable<string> refs)
    {
        foreach (var contentRef in refs.Reverse())
        {
            try
            {
                await Artifacts.DeleteAsync(
                    contentRef,
                    _workspaceAuthorityId,
                    value => value is ArtifactContentClasses.Quarantine or ArtifactContentClasses.Checkpoint,
                    CancellationToken.None).ConfigureAwait(false);
            }
            catch { }
        }
    }

    private static JsonObject DeletePreview(
        string relativePath,
        string sourceVersion,
        bool isTree,
        int entryCount,
        long totalBytes,
        TimeSpan ttl) =>
        new()
        {
            ["dry_run"] = true,
            ["relative_path"] = relativePath,
            ["source_version"] = sourceVersion,
            ["is_tree"] = isTree,
            ["entry_count"] = entryCount,
            ["total_bytes"] = totalBytes,
            ["ttl_seconds"] = (int)ttl.TotalSeconds,
        };

    private static JsonObject DeleteResult(QuarantineRecord record, QuarantineManifest manifest) =>
        new()
        {
            ["dry_run"] = false,
            ["quarantine_ref"] = record.QuarantineRef,
            ["original_relative_path"] = record.OriginalRelativePath,
            ["source_version"] = record.SourceVersion,
            ["manifest_hash"] = record.ManifestHash,
            ["expires_epoch_ms"] = record.ExpiresEpochMs,
            ["is_tree"] = record.IsTree,
            ["entry_count"] = manifest.Entries.Count,
            ["state"] = record.State,
        };

    private static JsonObject RestoreResult(
        QuarantineRecord record,
        string state,
        string target,
        string? recoveryRef,
        string? error = null,
        string? rollbackError = null)
    {
        var result = new JsonObject
        {
            ["quarantine_ref"] = record.QuarantineRef,
            ["state"] = state,
            ["target_relative_path"] = target,
        };
        if (!string.IsNullOrWhiteSpace(recoveryRef)) result["recovery_ref"] = recoveryRef;
        if (!string.IsNullOrWhiteSpace(error)) result["restore_error"] = error;
        if (!string.IsNullOrWhiteSpace(rollbackError)) result["rollback_error"] = rollbackError;
        return result;
    }

    private static JsonObject RecordMetadata(QuarantineRecord record, bool expired, QuarantineManifest? manifest = null)
    {
        var result = new JsonObject
        {
            ["quarantine_ref"] = record.QuarantineRef,
            ["original_relative_path"] = record.OriginalRelativePath,
            ["source_version"] = record.SourceVersion,
            ["manifest_hash"] = record.ManifestHash,
            ["is_tree"] = record.IsTree,
            ["created_epoch_ms"] = record.CreatedEpochMs,
            ["expires_epoch_ms"] = record.ExpiresEpochMs,
            ["expired"] = expired,
            ["state"] = record.State,
        };
        if (!string.IsNullOrWhiteSpace(record.LastRestoreTarget)) result["last_restore_target"] = record.LastRestoreTarget;
        if (!string.IsNullOrWhiteSpace(record.RecoveryContentRef)) result["recovery_ref"] = record.RecoveryContentRef;
        if (manifest is not null)
        {
            result["entry_count"] = manifest.Entries.Count;
            result["total_bytes"] = manifest.Entries.Where(e => e.EntryType == "file").Sum(e => e.SizeBytes);
        }
        return result;
    }

    private TimeSpan ResolveTtl(int ttlSeconds)
    {
        var ttl = ttlSeconds <= 0 ? _options.DefaultTtl : TimeSpan.FromSeconds(ttlSeconds);
        if (ttl <= TimeSpan.Zero || ttl > _options.MaxTtl)
            throw new FileMcpException($"Quarantine TTL must be positive and no more than {_options.MaxTtl.TotalHours:0.##} hours");
        return ttl;
    }

    private static string RequireExpectedVersion(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new FileMcpException("expected_version is required unless quarantine_delete is a dry run");
        return value.Trim();
    }

    private static string JoinRelative(string root, string child)
    {
        var normalizedRoot = root.Replace('\\', '/').TrimEnd('/');
        var normalizedChild = child.Replace('\\', '/').TrimStart('/');
        return string.IsNullOrEmpty(normalizedRoot) ? normalizedChild : normalizedRoot + "/" + normalizedChild;
    }

    private static int PathDepth(string path) =>
        string.IsNullOrEmpty(path) ? 0 : path.Count(c => c == '/' || c == '\\') + 1;

    private static bool EntryExists(string path)
    {
        try { _ = File.GetAttributes(path); return true; }
        catch (FileNotFoundException) { return false; }
        catch (DirectoryNotFoundException) { return false; }
    }

    private static bool PathEquals(string lhs, string rhs) =>
        string.Equals(
            Path.GetFullPath(lhs).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
            Path.GetFullPath(rhs).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
            StringComparison.OrdinalIgnoreCase);

    private void RequireContinue(ToolExecutionContext? context, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (context is not null && !context.TryContinue())
            throw new OperationCanceledException("Quarantine operation was cancelled or exceeded its budget", context.CancellationToken);
    }

    private void InvokeStage(string stage) => _stageForTests?.Invoke(stage);

    private void ThrowInjected(string stage)
    {
        var failure = _options.FaultInjector?.Invoke(stage);
        if (failure is not null) throw failure;
    }

    private static string Sha256Tagged(ReadOnlySpan<byte> bytes) =>
        "sha256:" + Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();

    private static void ValidateOptions(QuarantineServiceOptions options)
    {
        if (options.DefaultTtl <= TimeSpan.Zero || options.MaxTtl <= TimeSpan.Zero || options.DefaultTtl > options.MaxTtl)
            throw new ArgumentOutOfRangeException(nameof(options.DefaultTtl));
        if (options.MaxTtl > TimeSpan.FromDays(30))
            throw new ArgumentOutOfRangeException(nameof(options.MaxTtl));
        if (options.MaxTreeEntries < 1 || options.MaxTreeEntries > 100_000)
            throw new ArgumentOutOfRangeException(nameof(options.MaxTreeEntries));
        if (options.MaxTreeBytes < 1)
            throw new ArgumentOutOfRangeException(nameof(options.MaxTreeBytes));
        ArgumentNullException.ThrowIfNull(options.UtcNow);
    }

    private static void HardenDirectory(string path)
    {
        Directory.CreateDirectory(path);
        if (!OperatingSystem.IsWindows()) return;
        var sid = WindowsIdentity.GetCurrent().User
            ?? throw new FileMcpException("Could not determine current Windows user for quarantine storage");
        var security = new DirectorySecurity();
        security.SetOwner(sid);
        security.SetAccessRuleProtection(isProtected: true, preserveInheritance: false);
        security.AddAccessRule(new FileSystemAccessRule(
            sid,
            FileSystemRights.FullControl,
            InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
            PropagationFlags.None,
            AccessControlType.Allow));
        FileSystemAclExtensions.SetAccessControl(new DirectoryInfo(path), security);
    }

    private static void ValidateRecord(QuarantineRecord record)
    {
        if (string.IsNullOrWhiteSpace(record.QuarantineRef) ||
            string.IsNullOrWhiteSpace(record.WorkspaceAuthorityId) ||
            string.IsNullOrWhiteSpace(record.OriginalRelativePath) ||
            string.IsNullOrWhiteSpace(record.SourceVersion) ||
            string.IsNullOrWhiteSpace(record.ManifestHash))
            throw new FileMcpException("Quarantine metadata record is invalid");
        if (record.CreatedEpochMs < 0 || record.ExpiresEpochMs <= record.CreatedEpochMs)
            throw new FileMcpException("Quarantine metadata timestamps are invalid");
        if (record.State is not ("prepared" or "quarantined" or "restored" or "rolled_back" or "partial_recovery_required"))
            throw new FileMcpException("Quarantine metadata state is invalid");
    }

    private static void ValidateManifest(QuarantineManifest manifest)
    {
        if (manifest.SchemaVersion != SchemaVersion ||
            string.IsNullOrWhiteSpace(manifest.OriginalRelativePath) ||
            string.IsNullOrWhiteSpace(manifest.SourceVersion) ||
            manifest.ExpiresEpochMs <= manifest.CreatedEpochMs)
            throw new FileMcpException("Quarantine manifest is invalid");
        if (manifest.Entries is null || (!manifest.IsTree && manifest.Entries.Count != 1))
            throw new FileMcpException("Quarantine manifest entry count is invalid");
        foreach (var entry in manifest.Entries)
        {
            if (entry.EntryType is not ("file" or "directory"))
                throw new FileMcpException("Quarantine manifest entry type is invalid");
            if (entry.EntryType == "file" &&
                (string.IsNullOrWhiteSpace(entry.ContentRef) || string.IsNullOrWhiteSpace(entry.Sha256) || entry.SizeBytes < 0))
                throw new FileMcpException("Quarantine manifest file entry is invalid");
        }
    }

    private sealed class QuarantineIndex
    {
        public int SchemaVersion { get; set; }
        public List<QuarantineRecord> Records { get; set; } = [];
    }

    private sealed class QuarantineRecord
    {
        public string QuarantineRef { get; set; } = "";
        public string WorkspaceAuthorityId { get; set; } = "";
        public string OriginalRelativePath { get; set; } = "";
        public string SourceVersion { get; set; } = "";
        public string ManifestHash { get; set; } = "";
        public bool IsTree { get; set; }
        public long CreatedEpochMs { get; set; }
        public long ExpiresEpochMs { get; set; }
        public string State { get; set; } = "quarantined";
        public string? LastRestoreTarget { get; set; }
        public string? RecoveryContentRef { get; set; }
    }

    private sealed class QuarantineManifest
    {
        public int SchemaVersion { get; set; }
        public string OriginalRelativePath { get; set; } = "";
        public string SourceVersion { get; set; } = "";
        public bool IsTree { get; set; }
        public long CreatedEpochMs { get; set; }
        public long ExpiresEpochMs { get; set; }
        public List<QuarantineManifestEntry> Entries { get; set; } = [];
    }

    private sealed class QuarantineManifestEntry
    {
        public string RelativePath { get; set; } = "";
        public string EntryType { get; set; } = "";
        public long SizeBytes { get; set; }
        public string Sha256 { get; set; } = "";
        public string? ContentRef { get; set; }
    }

    private sealed record TreeEntry(
        string RelativePath,
        string AbsolutePath,
        string EntryType,
        long SizeBytes,
        string Sha256);

    private sealed record TreeSnapshot(
        string SourceVersion,
        List<TreeEntry> Entries,
        long TotalBytes);
}
