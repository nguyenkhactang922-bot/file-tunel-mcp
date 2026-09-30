using System.Text.Json;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed class WorkspaceCheckpointCrashForTestsException : Exception
{
    internal WorkspaceCheckpointCrashForTestsException(string message = "simulated checkpoint restore crash") : base(message) { }
}

internal sealed partial class WorkspaceCheckpointService
{
    private string RestoreJournalPath => Path.Combine(_metadataRoot, "restore-active-v1.json");

    internal async Task<JsonObject> RestoreAsync(
        string checkpointRef,
        string historyMode,
        bool dryRun,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        RequireContinue(context, cancellationToken);
        if (string.IsNullOrWhiteSpace(checkpointRef))
            throw new FileMcpException("checkpoint_ref must be non-empty");
        historyMode = string.IsNullOrWhiteSpace(historyMode) ? "preserve" : historyMode.Trim().ToLowerInvariant();
        if (historyMode is not ("preserve" or "move"))
            throw new FileMcpException("history_mode must be preserve or move");

        var recovered = await RecoverIncompleteRestoreAsync(preparedPolicy, context, cancellationToken).ConfigureAwait(false);
        if (recovered is not null) return recovered;

        var (record, manifest) = await GetCheckpointForRestoreAsync(checkpointRef, cancellationToken).ConfigureAwait(false);
        var repo = await _resolveRepo(manifest.RepositoryRelativePath, cancellationToken).ConfigureAwait(false);
        var currentHead = await ReadHeadOidAsync(repo, cancellationToken).ConfigureAwait(false);
        var targetHead = manifest.HeadOid;

        if (!string.Equals(currentHead, targetHead, StringComparison.Ordinal))
        {
            if (historyMode != "move")
                throw new FileMcpException("Checkpoint restore refused because repository HEAD diverged from checkpoint base");
            if (!_policy.AllowsExplicitHistoryMove)
                throw new FileMcpException("history_mode=move requires explicit custom high-risk local policy with write and delete effects");
            if (string.IsNullOrWhiteSpace(currentHead) || string.IsNullOrWhiteSpace(targetHead))
                throw new FileMcpException("History-moving restore does not support unborn HEAD state");
            _ = await RequireCommitAsync(repo, targetHead, cancellationToken).ConfigureAwait(false);
        }

        var plan = await BuildRestorePlanAsync(repo, manifest, cancellationToken).ConfigureAwait(false);
        if (dryRun)
            return RestoreResult(
                checkpointRef,
                "planned",
                manifest.RepositoryRelativePath,
                historyMode,
                currentHead,
                targetHead,
                rollbackRef: null,
                plan,
                recoveredIncomplete: false);

        _policy.Authorize("checkpoint_restore", preparedPolicy);
        RequireContinue(context, cancellationToken);

        var planStateBefore = await _captureSourceState(
            manifest.RepositoryRelativePath,
            plan.Paths.Select(item => item.RelativePath).ToArray(),
            cancellationToken).ConfigureAwait(false);
        var planStateId = RequiredString(planStateBefore, "source_state_id");

        var rollbackMetadata = await CaptureAsync(
            manifest.RepositoryRelativePath,
            manifest.IncludeUntracked,
            manifest.IncludeIgnored,
            manifest.IncludeGenerated,
            (int)_options.MaxTtl.TotalSeconds,
            _options.MaxEntries,
            _options.MaxTotalBytes,
            preparedPolicy,
            context,
            cancellationToken).ConfigureAwait(false);
        var rollbackRef = RequiredString(rollbackMetadata, "checkpoint_ref");
        var (rollbackRecord, rollbackManifest) = await GetCheckpointForRestoreAsync(rollbackRef, cancellationToken).ConfigureAwait(false);

        try
        {
            EnsureRollbackCoverage(plan, rollbackManifest);
            _options.RestoreStageForTests?.Invoke("after_restore_plan");
            RequireContinue(context, cancellationToken);

            var planStateAfter = await _captureSourceState(
                manifest.RepositoryRelativePath,
                plan.Paths.Select(item => item.RelativePath).ToArray(),
                cancellationToken).ConfigureAwait(false);
            if (!string.Equals(planStateId, RequiredString(planStateAfter, "source_state_id"), StringComparison.Ordinal))
            {
                await DeleteCheckpointInternalAsync(rollbackRecord, rollbackManifest, CancellationToken.None).ConfigureAwait(false);
                throw new FileMcpException("Repository changed after checkpoint restore plan validation");
            }

            var journal = new RestoreJournal
            {
                TransactionId = Guid.NewGuid().ToString("N"),
                Phase = "prepared",
                TargetCheckpointRef = checkpointRef,
                RollbackCheckpointRef = rollbackRef,
                RepositoryRelativePath = manifest.RepositoryRelativePath,
                OriginalHeadOid = currentHead,
                TargetHeadOid = targetHead,
                HistoryMode = historyMode,
                StartedEpochMs = _options.UtcNow().ToUnixTimeMilliseconds(),
            };
            PersistRestoreJournal(journal);

            var mutationStarted = false;
            try
            {
                if (!string.Equals(currentHead, targetHead, StringComparison.Ordinal))
                {
                    mutationStarted = true;
                    await MoveHeadAsync(repo, currentHead!, targetHead!, cancellationToken).ConfigureAwait(false);
                }

                await ApplyRestorePlanAsync(
                    repo,
                    manifest,
                    plan,
                    preparedPolicy,
                    context,
                    cancellationToken,
                    isRollback: false,
                    mutationStarted: () => mutationStarted = true).ConfigureAwait(false);

                _options.RestoreStageForTests?.Invoke("before_restore_verify");
                await VerifyRestorePlanAsync(repo, manifest, plan, cancellationToken).ConfigureAwait(false);
                journal.Phase = "verified";
                PersistRestoreJournal(journal);

                var cleanupPending = false;
                try
                {
                    await DeleteCheckpointInternalAsync(rollbackRecord, rollbackManifest, CancellationToken.None).ConfigureAwait(false);
                    DeleteRestoreJournal();
                }
                catch
                {
                    cleanupPending = true;
                }

                var restored = RestoreResult(
                    checkpointRef,
                    "restored",
                    manifest.RepositoryRelativePath,
                    historyMode,
                    currentHead,
                    targetHead,
                    cleanupPending ? rollbackRef : null,
                    plan,
                    recoveredIncomplete: false);
                restored["cleanup_pending"] = cleanupPending;
                return restored;
            }
            catch (WorkspaceCheckpointCrashForTestsException)
            {
                throw;
            }
            catch (Exception restoreFailure)
            {
                if (!mutationStarted)
                {
                    try { await DeleteCheckpointInternalAsync(rollbackRecord, rollbackManifest, CancellationToken.None).ConfigureAwait(false); } catch { }
                    DeleteRestoreJournalBestEffort();
                    throw;
                }

                try
                {
                    _options.RestoreStageForTests?.Invoke("before_restore_rollback");
                    await RollbackFromJournalAsync(journal, rollbackRecord, rollbackManifest, preparedPolicy, context, cancellationToken)
                        .ConfigureAwait(false);
                    journal.Phase = "rolled_back";
                    PersistRestoreJournal(journal);
                    try
                    {
                        await DeleteCheckpointInternalAsync(rollbackRecord, rollbackManifest, CancellationToken.None).ConfigureAwait(false);
                        DeleteRestoreJournal();
                    }
                    catch { }

                    return RestoreResult(
                        checkpointRef,
                        "rolled_back",
                        manifest.RepositoryRelativePath,
                        historyMode,
                        currentHead,
                        targetHead,
                        rollbackRef: File.Exists(RestoreJournalPath) ? rollbackRef : null,
                        plan,
                        recoveredIncomplete: false,
                        error: restoreFailure.Message);
                }
                catch (Exception rollbackFailure)
                {
                    journal.Phase = "partial_recovery_required";
                    PersistRestoreJournalBestEffort(journal);
                    return RestoreResult(
                        checkpointRef,
                        "partial_recovery_required",
                        manifest.RepositoryRelativePath,
                        historyMode,
                        currentHead,
                        targetHead,
                        rollbackRef,
                        plan,
                        recoveredIncomplete: false,
                        error: restoreFailure.Message,
                        rollbackError: rollbackFailure.Message);
                }
            }
        }
        catch
        {
            if (!File.Exists(RestoreJournalPath))
            {
                try
                {
                    await DeleteCheckpointInternalAsync(
                        rollbackRecord,
                        rollbackManifest,
                        CancellationToken.None).ConfigureAwait(false);
                }
                catch { }
            }
            throw;
        }
    }

    private async Task<JsonObject?> RecoverIncompleteRestoreAsync(
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        var journal = LoadRestoreJournal();
        if (journal is null) return null;

        var (rollbackRecord, rollbackManifest) = await GetCheckpointForRestoreAsync(
            journal.RollbackCheckpointRef,
            cancellationToken).ConfigureAwait(false);

        if (journal.Phase == "verified")
        {
            try
            {
                await DeleteCheckpointInternalAsync(rollbackRecord, rollbackManifest, CancellationToken.None).ConfigureAwait(false);
                DeleteRestoreJournal();
            }
            catch { }
            var result = RestoreResult(
                journal.TargetCheckpointRef,
                "restored",
                journal.RepositoryRelativePath,
                journal.HistoryMode,
                journal.OriginalHeadOid,
                journal.TargetHeadOid,
                File.Exists(RestoreJournalPath) ? journal.RollbackCheckpointRef : null,
                new RestorePlan(),
                recoveredIncomplete: true);
            result["cleanup_pending"] = File.Exists(RestoreJournalPath);
            return result;
        }

        if (journal.Phase == "rolled_back")
        {
            try
            {
                await DeleteCheckpointInternalAsync(rollbackRecord, rollbackManifest, CancellationToken.None).ConfigureAwait(false);
                DeleteRestoreJournal();
            }
            catch { }
            return RestoreResult(
                journal.TargetCheckpointRef,
                "rolled_back",
                journal.RepositoryRelativePath,
                journal.HistoryMode,
                journal.OriginalHeadOid,
                journal.TargetHeadOid,
                File.Exists(RestoreJournalPath) ? journal.RollbackCheckpointRef : null,
                new RestorePlan(),
                recoveredIncomplete: true);
        }

        if (journal.Phase == "partial_recovery_required")
        {
            return RestoreResult(
                journal.TargetCheckpointRef,
                "partial_recovery_required",
                journal.RepositoryRelativePath,
                journal.HistoryMode,
                journal.OriginalHeadOid,
                journal.TargetHeadOid,
                journal.RollbackCheckpointRef,
                new RestorePlan(),
                recoveredIncomplete: true,
                error: "Previous checkpoint restore requires recovery");
        }

        try
        {
            await RollbackFromJournalAsync(journal, rollbackRecord, rollbackManifest, preparedPolicy, context, cancellationToken)
                .ConfigureAwait(false);
            journal.Phase = "rolled_back";
            PersistRestoreJournal(journal);
            try
            {
                await DeleteCheckpointInternalAsync(rollbackRecord, rollbackManifest, CancellationToken.None).ConfigureAwait(false);
                DeleteRestoreJournal();
            }
            catch { }
            return RestoreResult(
                journal.TargetCheckpointRef,
                "rolled_back",
                journal.RepositoryRelativePath,
                journal.HistoryMode,
                journal.OriginalHeadOid,
                journal.TargetHeadOid,
                File.Exists(RestoreJournalPath) ? journal.RollbackCheckpointRef : null,
                new RestorePlan(),
                recoveredIncomplete: true,
                error: "Recovered interrupted checkpoint restore");
        }
        catch (Exception rollbackFailure)
        {
            journal.Phase = "partial_recovery_required";
            PersistRestoreJournalBestEffort(journal);
            return RestoreResult(
                journal.TargetCheckpointRef,
                "partial_recovery_required",
                journal.RepositoryRelativePath,
                journal.HistoryMode,
                journal.OriginalHeadOid,
                journal.TargetHeadOid,
                journal.RollbackCheckpointRef,
                new RestorePlan(),
                recoveredIncomplete: true,
                error: "Interrupted checkpoint restore rollback failed",
                rollbackError: rollbackFailure.Message);
        }
    }

    private async Task RollbackFromJournalAsync(
        RestoreJournal journal,
        CheckpointRecord rollbackRecord,
        CheckpointManifest rollbackManifest,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        var repo = await _resolveRepo(journal.RepositoryRelativePath, cancellationToken).ConfigureAwait(false);
        var currentHead = await ReadHeadOidAsync(repo, cancellationToken).ConfigureAwait(false);
        if (!string.Equals(currentHead, journal.OriginalHeadOid, StringComparison.Ordinal))
        {
            if (journal.HistoryMode != "move" ||
                string.IsNullOrWhiteSpace(journal.OriginalHeadOid) ||
                string.IsNullOrWhiteSpace(currentHead))
                throw new FileMcpException("Rollback refused because repository HEAD no longer matches restore transaction");
            await MoveHeadAsync(repo, currentHead, journal.OriginalHeadOid!, cancellationToken).ConfigureAwait(false);
        }

        var rollbackPlan = await BuildRestorePlanAsync(repo, rollbackManifest, cancellationToken).ConfigureAwait(false);
        _options.RestoreStageForTests?.Invoke("during_restore_rollback");
        await ApplyRestorePlanAsync(
            repo,
            rollbackManifest,
            rollbackPlan,
            preparedPolicy,
            context,
            cancellationToken,
            isRollback: true,
            mutationStarted: static () => { }).ConfigureAwait(false);
        await VerifyRestorePlanAsync(repo, rollbackManifest, rollbackPlan, cancellationToken).ConfigureAwait(false);
    }

    private async Task<RestorePlan> BuildRestorePlanAsync(
        string repo,
        CheckpointManifest manifest,
        CancellationToken cancellationToken)
    {
        var currentStaged = SplitNul(await _runGit(
            repo, ["diff", "--cached", "--name-only", "--diff-filter=ACMRD", "-z", "--"],
            FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false));
        var currentUnstaged = SplitNul(await _runGit(
            repo, ["diff", "--name-only", "--diff-filter=ACMRD", "-z", "--"],
            FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false));
        var currentUntracked = manifest.IncludeUntracked
            ? SplitNul(await _runGit(
                repo, ["ls-files", "--others", "--exclude-standard", "-z", "--"],
                FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false))
            : [];
        var currentIgnored = manifest.IncludeIgnored
            ? SplitNul(await _runGit(
                repo, ["ls-files", "--others", "--ignored", "--exclude-standard", "-z", "--"],
                FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false))
            : [];
        var currentHead = await ReadHeadOidAsync(repo, cancellationToken).ConfigureAwait(false);
        var historyChanged = !string.IsNullOrWhiteSpace(currentHead) &&
                             !string.IsNullOrWhiteSpace(manifest.HeadOid) &&
                             !string.Equals(currentHead, manifest.HeadOid, StringComparison.OrdinalIgnoreCase)
            ? SplitNul(await _runGit(
                repo, ["diff", "--name-only", "-z", currentHead!, manifest.HeadOid!, "--"],
                FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false))
            : [];

        IEnumerable<string> Managed(IEnumerable<string> paths) =>
            manifest.IncludeGenerated ? paths : paths.Where(path => !IsGeneratedPath(path));

        var targetEntries = manifest.Entries.ToDictionary(entry => entry.RelativePath, StringComparer.Ordinal);
        var allPaths = targetEntries.Keys
            .Concat(Managed(currentStaged))
            .Concat(Managed(currentUnstaged))
            .Concat(Managed(currentUntracked))
            .Concat(Managed(currentIgnored))
            .Concat(Managed(historyChanged))
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();

        if (allPaths.Length > _options.MaxEntries)
            throw new FileMcpException("Checkpoint restore plan exceeds maximum entry count");

        var plan = new RestorePlan();
        foreach (var path in allPaths)
        {
            ValidateRepoRelativePath(path);
            targetEntries.TryGetValue(path, out var target);
            var baseEntry = await ReadTreeEntryAsync(repo, manifest.HeadOid, path, cancellationToken).ConfigureAwait(false);
            var item = new RestorePathPlan { RelativePath = path };

            if (target is not null && target.Generated && !manifest.IncludeGenerated)
            {
                item.SkipIndex = target.Staged;
                item.SkipWorktree = true;
                item.SkipReason = "generated";
            }
            else
            {
                await ResolveDesiredIndexAsync(item, target, baseEntry, cancellationToken).ConfigureAwait(false);
                await ResolveDesiredWorktreeAsync(item, target, baseEntry, repo, manifest.HeadOid, cancellationToken).ConfigureAwait(false);
            }

            var full = Path.GetFullPath(Path.Combine(repo, path.Replace('/', Path.DirectorySeparatorChar)));
            EnsurePathInsideRepo(repo, full);
            var exists = File.Exists(full);
            if (exists || Directory.Exists(full))
            {
                var attrs = File.GetAttributes(full);
                if ((attrs & FileAttributes.ReparsePoint) != 0)
                    throw new FileMcpException($"Checkpoint restore refuses symlink/reparse target: {path}");
                if ((attrs & FileAttributes.Directory) != 0)
                    throw new FileMcpException($"Checkpoint restore only mutates regular files: {path}");
            }

            if (!item.SkipWorktree)
            {
                item.CurrentWorktreeExists = exists;
                item.NeedsWorktreeMutation = item.DesiredWorktreeExists != exists;
                if (item.DesiredWorktreeExists && exists && item.DesiredWorktreeSha256 is not null)
                {
                    using var current = new FileStream(full, FileMode.Open, FileAccess.Read, FileShare.Read, 64 * 1024, FileOptions.SequentialScan);
                    var currentHash = "sha256:" + Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(current)).ToLowerInvariant();
                    item.NeedsWorktreeMutation = !string.Equals(currentHash, item.DesiredWorktreeSha256, StringComparison.Ordinal);
                }

                if (item.NeedsWorktreeMutation)
                {
                    var sharedRelative = _resolver.RelativePath(full);
                    item.WorktreeGuard = exists
                        ? _mutationGuard.CaptureExisting(sharedRelative)
                        : _mutationGuard.CaptureNewTarget(sharedRelative);
                }
            }

            if (item.SkipIndex) plan.HasIndexSkips = true;
            if (item.SkipWorktree) plan.HasWorktreeSkips = true;
            if (item.SkipIndex || item.SkipWorktree) plan.SkippedCount++;
            plan.Paths.Add(item);
        }
        return plan;
    }

    private async Task ResolveDesiredIndexAsync(
        RestorePathPlan item,
        CheckpointManifestEntry? target,
        GitTreeEntry? baseEntry,
        CancellationToken cancellationToken)
    {
        if (target is not null && target.Staged)
        {
            if (!string.IsNullOrWhiteSpace(target.IndexExcludedReason))
            {
                item.SkipIndex = true;
                item.SkipReason = target.IndexExcludedReason;
                return;
            }
            if (target.IndexContentRef is null)
            {
                item.DesiredIndexExists = false;
                return;
            }
            if (string.IsNullOrWhiteSpace(target.IndexMode))
                throw new FileMcpException($"Checkpoint staged restore requires schema-v2 index_mode for {target.RelativePath}");
            ValidateIndexMode(target.IndexMode);
            var payload = await ReadCheckpointPayloadAsync(
                target.IndexContentRef,
                target.IndexSha256,
                target.IndexSizeBytes,
                cancellationToken).ConfigureAwait(false);
            item.DesiredIndexExists = true;
            item.DesiredIndexMode = target.IndexMode;
            item.DesiredIndexBytes = payload;
            return;
        }

        if (baseEntry is null)
        {
            item.DesiredIndexExists = false;
            return;
        }
        ValidateIndexMode(baseEntry.Mode);
        item.DesiredIndexExists = true;
        item.DesiredIndexMode = baseEntry.Mode;
        item.DesiredIndexOid = baseEntry.Oid;
    }

    private async Task ResolveDesiredWorktreeAsync(
        RestorePathPlan item,
        CheckpointManifestEntry? target,
        GitTreeEntry? baseEntry,
        string repo,
        string? headOid,
        CancellationToken cancellationToken)
    {
        if (target is not null)
        {
            if (!string.IsNullOrWhiteSpace(target.WorktreeExcludedReason))
            {
                item.SkipWorktree = true;
                item.SkipReason ??= target.WorktreeExcludedReason;
                return;
            }
            if (!target.WorktreeExists)
            {
                item.DesiredWorktreeExists = false;
                return;
            }
            if (target.WorktreeContentRef is null || string.IsNullOrWhiteSpace(target.WorktreeSha256))
                throw new FileMcpException($"Checkpoint worktree payload is missing for {target.RelativePath}");
            item.DesiredWorktreeBytes = await ReadCheckpointPayloadAsync(
                target.WorktreeContentRef,
                target.WorktreeSha256,
                target.WorktreeSizeBytes,
                cancellationToken).ConfigureAwait(false);
            item.DesiredWorktreeExists = true;
            item.DesiredWorktreeSha256 = target.WorktreeSha256;
            item.DesiredWorktreeMode = target.IndexMode ?? baseEntry?.Mode;
            return;
        }

        if (baseEntry is null)
        {
            item.DesiredWorktreeExists = false;
            return;
        }
        if (baseEntry.Type != "blob" || baseEntry.Mode is not ("100644" or "100755"))
            throw new FileMcpException($"Checkpoint restore cannot materialize Git tree mode {baseEntry.Mode} for {item.RelativePath}");
        if (string.IsNullOrWhiteSpace(headOid))
            throw new FileMcpException("Checkpoint base HEAD is unavailable for worktree restore");
        var data = await _readGitObjectBlob(repo, baseEntry.Oid, cancellationToken).ConfigureAwait(false);
        item.DesiredWorktreeExists = true;
        item.DesiredWorktreeBytes = data;
        item.DesiredWorktreeSha256 = FileVersionService.Sha256Tagged(data);
        item.DesiredWorktreeMode = baseEntry.Mode;
    }

    private async Task ApplyRestorePlanAsync(
        string repo,
        CheckpointManifest manifest,
        RestorePlan plan,
        PolicySnapshot preparedPolicy,
        ToolExecutionContext? context,
        CancellationToken cancellationToken,
        bool isRollback,
        Action mutationStarted)
    {
        foreach (var item in plan.Paths.Where(item => !item.SkipWorktree && item.NeedsWorktreeMutation))
        {
            RequireContinue(context, cancellationToken);
            _policy.Authorize("checkpoint_restore", preparedPolicy);
            if (item.WorktreeGuard is null)
                throw new FileMcpException("Checkpoint restore Mutation Guard is missing");
            _ = _mutationGuard.Verify(item.WorktreeGuard);
            mutationStarted();

            var full = Path.GetFullPath(Path.Combine(repo, item.RelativePath.Replace('/', Path.DirectorySeparatorChar)));
            EnsurePathInsideRepo(repo, full);
            if (!item.DesiredWorktreeExists)
            {
                if (File.Exists(full)) File.Delete(full);
            }
            else
            {
                var parent = Path.GetDirectoryName(full) ?? throw new FileMcpException("Checkpoint restore target parent is unavailable");
                if (!Directory.Exists(parent))
                    throw new FileMcpException($"Checkpoint restore target parent must already exist: {item.RelativePath}");
                var temp = full + ".filemcp-checkpoint-restore-" + Guid.NewGuid().ToString("N") + ".tmp";
                try
                {
                    await File.WriteAllBytesAsync(temp, item.DesiredWorktreeBytes!, cancellationToken).ConfigureAwait(false);
                    using (var handle = new FileStream(temp, FileMode.Open, FileAccess.ReadWrite, FileShare.None))
                        handle.Flush(flushToDisk: true);
                    _ = _mutationGuard.Verify(item.WorktreeGuard);
                    File.Move(temp, full, overwrite: File.Exists(full));
                }
                finally
                {
                    try { File.Delete(temp); } catch { }
                }
            }
            _options.RestoreStageForTests?.Invoke((isRollback ? "after_rollback_publish:" : "after_restore_publish:") + item.RelativePath);
        }

        foreach (var item in plan.Paths.Where(item => !item.SkipIndex))
        {
            RequireContinue(context, cancellationToken);
            _policy.Authorize("checkpoint_restore", preparedPolicy);
            mutationStarted();
            if (!item.DesiredIndexExists)
            {
                await _runGit(
                    repo,
                    ["update-index", "--force-remove", "--", item.RelativePath],
                    FileMcpConstants.MaxGitSafetyOutputBytes,
                    true,
                    cancellationToken).ConfigureAwait(false);
                continue;
            }

            var oid = item.DesiredIndexOid;
            if (oid is null)
            {
                oid = await WriteGitBlobAsync(repo, item.DesiredIndexBytes!, cancellationToken).ConfigureAwait(false);
                item.DesiredIndexOid = oid;
            }
            await _runGit(
                repo,
                ["update-index", "--add", "--cacheinfo", $"{item.DesiredIndexMode},{oid},{item.RelativePath}"],
                FileMcpConstants.MaxGitSafetyOutputBytes,
                true,
                cancellationToken).ConfigureAwait(false);
        }
    }

    private async Task VerifyRestorePlanAsync(
        string repo,
        CheckpointManifest manifest,
        RestorePlan plan,
        CancellationToken cancellationToken)
    {
        var head = await ReadHeadOidAsync(repo, cancellationToken).ConfigureAwait(false);
        if (!string.Equals(head, manifest.HeadOid, StringComparison.Ordinal))
            throw new FileMcpException("Checkpoint restore verification detected unexpected HEAD");

        foreach (var item in plan.Paths)
        {
            if (!item.SkipIndex)
            {
                var current = await ReadIndexEntryAsync(repo, item.RelativePath, cancellationToken).ConfigureAwait(false);
                if (!item.DesiredIndexExists)
                {
                    if (current is not null)
                        throw new FileMcpException($"Checkpoint restore index verification failed: {item.RelativePath}");
                }
                else if (current is null ||
                         !string.Equals(current.Mode, item.DesiredIndexMode, StringComparison.Ordinal) ||
                         !string.Equals(current.Oid, item.DesiredIndexOid, StringComparison.OrdinalIgnoreCase))
                {
                    throw new FileMcpException($"Checkpoint restore index verification failed: {item.RelativePath}");
                }
            }

            if (!item.SkipWorktree)
            {
                var full = Path.GetFullPath(Path.Combine(repo, item.RelativePath.Replace('/', Path.DirectorySeparatorChar)));
                EnsurePathInsideRepo(repo, full);
                if (!item.DesiredWorktreeExists)
                {
                    if (File.Exists(full) || Directory.Exists(full))
                        throw new FileMcpException($"Checkpoint restore worktree verification failed: {item.RelativePath}");
                }
                else
                {
                    if (!File.Exists(full))
                        throw new FileMcpException($"Checkpoint restore worktree verification failed: {item.RelativePath}");
                    using var stream = new FileStream(full, FileMode.Open, FileAccess.Read, FileShare.Read, 64 * 1024, FileOptions.SequentialScan);
                    var hash = "sha256:" + Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(stream)).ToLowerInvariant();
                    if (!string.Equals(hash, item.DesiredWorktreeSha256, StringComparison.Ordinal))
                        throw new FileMcpException($"Checkpoint restore worktree digest verification failed: {item.RelativePath}");
                }
            }
        }

        if (!plan.HasIndexSkips)
        {
            var rawIndex = await _runGit(
                repo,
                ["ls-files", "-s", "-z"],
                FileMcpConstants.MaxGitSafetyOutputBytes,
                false,
                cancellationToken).ConfigureAwait(false);
            if (!string.Equals(FileVersionService.Sha256Tagged(rawIndex), manifest.IndexFingerprint, StringComparison.Ordinal))
                throw new FileMcpException("Checkpoint restore final index fingerprint mismatch");
        }
    }

    private void EnsureRollbackCoverage(RestorePlan targetPlan, CheckpointManifest rollbackManifest)
    {
        var rollbackEntries = rollbackManifest.Entries.ToDictionary(entry => entry.RelativePath, StringComparer.Ordinal);
        foreach (var item in targetPlan.Paths.Where(item => item.NeedsWorktreeMutation))
        {
            if (!item.CurrentWorktreeExists) continue;
            if (!rollbackEntries.TryGetValue(item.RelativePath, out var rollbackEntry))
                continue; // Clean tracked state is recoverable from rollback HEAD.
            if (!string.IsNullOrWhiteSpace(rollbackEntry.WorktreeExcludedReason))
                throw new FileMcpException($"Rollback checkpoint cannot cover {item.RelativePath}: {rollbackEntry.WorktreeExcludedReason}");
        }
        foreach (var entry in rollbackManifest.Entries.Where(entry => entry.Staged && !string.IsNullOrWhiteSpace(entry.IndexExcludedReason)))
            throw new FileMcpException($"Rollback checkpoint cannot cover staged index state for {entry.RelativePath}: {entry.IndexExcludedReason}");
    }

    private async Task<(CheckpointRecord Record, CheckpointManifest Manifest)> GetCheckpointForRestoreAsync(
        string checkpointRef,
        CancellationToken cancellationToken)
    {
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await PruneExpiredAsync(cancellationToken).ConfigureAwait(false);
        CheckpointRecord record;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            record = _records.SingleOrDefault(item => item.CheckpointRef == checkpointRef)
                ?? throw new FileMcpException("Unknown or expired checkpoint_ref");
        }
        finally { _gate.Release(); }
        var manifest = await LoadManifestAsync(record, cancellationToken).ConfigureAwait(false);
        return (record, manifest);
    }

    private async Task<byte[]> ReadCheckpointPayloadAsync(
        string contentRef,
        string? expectedHash,
        long expectedSize,
        CancellationToken cancellationToken)
    {
        var descriptor = await Artifacts.ResolveAsync(
            contentRef,
            _workspaceAuthorityId,
            value => value == ArtifactContentClasses.Checkpoint,
            cancellationToken).ConfigureAwait(false);
        if (!string.IsNullOrWhiteSpace(expectedHash) && !string.Equals(descriptor.BlobId, expectedHash, StringComparison.Ordinal))
            throw new FileMcpException("Checkpoint payload digest mismatch");
        if (expectedSize >= 0 && descriptor.SizeBytes != expectedSize)
            throw new FileMcpException("Checkpoint payload size mismatch");
        if (descriptor.SizeBytes > _options.MaxSingleFileBytes)
            throw new FileMcpException("Checkpoint payload exceeds restore single-file limit");
        await using var memory = new MemoryStream((int)descriptor.SizeBytes);
        await Artifacts.CopyToAsync(
            contentRef,
            _workspaceAuthorityId,
            value => value == ArtifactContentClasses.Checkpoint,
            memory,
            cancellationToken).ConfigureAwait(false);
        var data = memory.ToArray();
        if (!string.IsNullOrWhiteSpace(expectedHash) &&
            !string.Equals(FileVersionService.Sha256Tagged(data), expectedHash, StringComparison.Ordinal))
            throw new FileMcpException("Checkpoint payload digest verification failed");
        return data;
    }

    private async Task<GitTreeEntry?> ReadTreeEntryAsync(
        string repo,
        string? headOid,
        string path,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(headOid)) return null;
        var raw = await _runGit(
            repo,
            ["ls-tree", "-z", headOid, "--", path],
            FileMcpConstants.MaxGitSafetyOutputBytes,
            false,
            cancellationToken).ConfigureAwait(false);
        if (string.IsNullOrEmpty(raw)) return null;
        var line = raw.TrimEnd(' ');
        var tab = line.IndexOf('	');
        if (tab <= 0) throw new FileMcpException("Checkpoint restore could not parse Git tree entry");
        var metadata = line[..tab].Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (metadata.Length != 3) throw new FileMcpException("Checkpoint restore Git tree entry is invalid");
        return new GitTreeEntry(metadata[0], metadata[1], metadata[2]);
    }

    private async Task<GitTreeEntry?> ReadIndexEntryAsync(
        string repo,
        string path,
        CancellationToken cancellationToken)
    {
        var listed = await _runGit(
            repo,
            ["ls-files", "-s", "--", path],
            FileMcpConstants.MaxGitSafetyOutputBytes,
            true,
            cancellationToken).ConfigureAwait(false);
        foreach (var line in listed.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var tab = line.IndexOf('	');
            if (tab <= 0) continue;
            var metadata = line[..tab].Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (metadata.Length < 3 || metadata[2] != "0") continue;
            return new GitTreeEntry(metadata[0], "blob", metadata[1]);
        }
        return null;
    }

    private async Task<string> WriteGitBlobAsync(string repo, byte[] data, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(_metadataRoot);
        var temp = Path.Combine(_metadataRoot, "git-blob-" + Guid.NewGuid().ToString("N") + ".tmp");
        try
        {
            await File.WriteAllBytesAsync(temp, data, cancellationToken).ConfigureAwait(false);
            var oid = (await _runGit(
                repo,
                ["hash-object", "-w", "--", temp],
                FileMcpConstants.MaxGitSafetyOutputBytes,
                true,
                cancellationToken).ConfigureAwait(false)).Trim();
            if (oid.Length is < 7 or > 128 || !oid.All(Uri.IsHexDigit))
                throw new FileMcpException("Checkpoint restore could not validate Git blob identity");
            return oid;
        }
        finally
        {
            try { File.Delete(temp); } catch { }
        }
    }

    private async Task<string?> ReadHeadOidAsync(string repo, CancellationToken cancellationToken)
    {
        try
        {
            var value = (await _runGit(
                repo,
                ["rev-parse", "--verify", "HEAD"],
                FileMcpConstants.MaxGitSafetyOutputBytes,
                true,
                cancellationToken).ConfigureAwait(false)).Trim();
            if (value.Length is < 7 or > 128 || !value.All(Uri.IsHexDigit))
                throw new FileMcpException("Checkpoint restore could not validate Git HEAD");
            return value;
        }
        catch (FileMcpException ex) when (
            ex.Message.Contains("needed a single revision", StringComparison.OrdinalIgnoreCase) ||
            ex.Message.Contains("unknown revision", StringComparison.OrdinalIgnoreCase) ||
            ex.Message.Contains("ambiguous argument", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }
    }

    private async Task<string> RequireCommitAsync(string repo, string oid, CancellationToken cancellationToken)
    {
        var value = (await _runGit(
            repo,
            ["rev-parse", "--verify", oid + "^{commit}"],
            FileMcpConstants.MaxGitSafetyOutputBytes,
            true,
            cancellationToken).ConfigureAwait(false)).Trim();
        if (!string.Equals(value, oid, StringComparison.OrdinalIgnoreCase))
            throw new FileMcpException("Checkpoint restore target HEAD is not the expected commit");
        return value;
    }

    private async Task MoveHeadAsync(string repo, string from, string to, CancellationToken cancellationToken)
    {
        _ = await RequireCommitAsync(repo, to, cancellationToken).ConfigureAwait(false);
        await _runGit(
            repo,
            ["update-ref", "HEAD", to, from],
            FileMcpConstants.MaxGitSafetyOutputBytes,
            true,
            cancellationToken).ConfigureAwait(false);
        var current = await ReadHeadOidAsync(repo, cancellationToken).ConfigureAwait(false);
        if (!string.Equals(current, to, StringComparison.OrdinalIgnoreCase))
            throw new FileMcpException("Checkpoint restore history move verification failed");
    }

    private async Task DeleteCheckpointInternalAsync(
        CheckpointRecord record,
        CheckpointManifest manifest,
        CancellationToken cancellationToken)
    {
        foreach (var contentRef in ManifestContentRefs(manifest).Append(record.CheckpointRef).Distinct(StringComparer.Ordinal))
        {
            try
            {
                await Artifacts.DeleteAsync(
                    contentRef,
                    _workspaceAuthorityId,
                    value => value == ArtifactContentClasses.Checkpoint,
                    cancellationToken).ConfigureAwait(false);
            }
            catch (FileMcpException) { }
        }
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var candidate = _records.Where(item => item.CheckpointRef != record.CheckpointRef).ToList();
            PersistIndex(candidate);
            _records = candidate;
        }
        finally { _gate.Release(); }
    }

    private void PersistRestoreJournal(RestoreJournal journal)
    {
        Directory.CreateDirectory(_metadataRoot);
        var temp = RestoreJournalPath + ".tmp-" + Guid.NewGuid().ToString("N");
        File.WriteAllBytes(temp, JsonSerializer.SerializeToUtf8Bytes(journal, _json));
        if (File.Exists(RestoreJournalPath)) File.Move(temp, RestoreJournalPath, overwrite: true);
        else File.Move(temp, RestoreJournalPath);
    }

    private void PersistRestoreJournalBestEffort(RestoreJournal journal)
    {
        try { PersistRestoreJournal(journal); } catch { }
    }

    private RestoreJournal? LoadRestoreJournal()
    {
        if (!File.Exists(RestoreJournalPath)) return null;
        try
        {
            return JsonSerializer.Deserialize<RestoreJournal>(File.ReadAllBytes(RestoreJournalPath), _json)
                ?? throw new FileMcpException("Checkpoint restore journal is invalid");
        }
        catch (JsonException ex)
        {
            throw new FileMcpException("Checkpoint restore journal is corrupt: " + ex.Message);
        }
    }

    private void DeleteRestoreJournal()
    {
        if (File.Exists(RestoreJournalPath)) File.Delete(RestoreJournalPath);
    }

    private void DeleteRestoreJournalBestEffort()
    {
        try { DeleteRestoreJournal(); } catch { }
    }

    private static void ValidateIndexMode(string mode)
    {
        if (mode is not ("100644" or "100755" or "120000"))
            throw new FileMcpException($"Checkpoint restore does not support Git index mode {mode}");
    }

    private static void EnsurePathInsideRepo(string repo, string full)
    {
        var root = Path.GetFullPath(repo).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var prefix = root + Path.DirectorySeparatorChar;
        if (!full.StartsWith(prefix, OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal))
            throw new FileMcpException("Checkpoint restore path escaped repository");
    }

    private JsonObject RestoreResult(
        string checkpointRef,
        string state,
        string repoRelative,
        string historyMode,
        string? originalHead,
        string? targetHead,
        string? rollbackRef,
        RestorePlan plan,
        bool recoveredIncomplete,
        string? error = null,
        string? rollbackError = null)
    {
        return new JsonObject
        {
            ["checkpoint_ref"] = checkpointRef,
            ["state"] = state,
            ["repository_relative_path"] = repoRelative,
            ["history_mode"] = historyMode,
            ["original_head_oid"] = originalHead,
            ["target_head_oid"] = targetHead,
            ["rollback_checkpoint_ref"] = rollbackRef,
            ["path_count"] = plan.Paths.Count,
            ["skipped_count"] = plan.SkippedCount,
            ["recovered_incomplete"] = recoveredIncomplete,
            ["error"] = error,
            ["rollback_error"] = rollbackError,
        };
    }

    private sealed class RestorePlan
    {
        public List<RestorePathPlan> Paths { get; } = [];
        public bool HasIndexSkips { get; set; }
        public bool HasWorktreeSkips { get; set; }
        public int SkippedCount { get; set; }
    }

    private sealed class RestorePathPlan
    {
        public string RelativePath { get; init; } = "";
        public bool SkipIndex { get; set; }
        public bool SkipWorktree { get; set; }
        public string? SkipReason { get; set; }
        public bool DesiredIndexExists { get; set; }
        public string? DesiredIndexMode { get; set; }
        public string? DesiredIndexOid { get; set; }
        public byte[]? DesiredIndexBytes { get; set; }
        public bool DesiredWorktreeExists { get; set; }
        public byte[]? DesiredWorktreeBytes { get; set; }
        public string? DesiredWorktreeSha256 { get; set; }
        public string? DesiredWorktreeMode { get; set; }
        public bool CurrentWorktreeExists { get; set; }
        public bool NeedsWorktreeMutation { get; set; }
        public AuthorizedPathSnapshot? WorktreeGuard { get; set; }
    }

    private sealed record GitTreeEntry(string Mode, string Type, string Oid);

    private sealed class RestoreJournal
    {
        public string TransactionId { get; set; } = "";
        public string Phase { get; set; } = "prepared";
        public string TargetCheckpointRef { get; set; } = "";
        public string RollbackCheckpointRef { get; set; } = "";
        public string RepositoryRelativePath { get; set; } = "";
        public string? OriginalHeadOid { get; set; }
        public string? TargetHeadOid { get; set; }
        public string HistoryMode { get; set; } = "preserve";
        public long StartedEpochMs { get; set; }
    }
}
