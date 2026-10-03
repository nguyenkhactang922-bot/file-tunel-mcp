using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed record EvidenceRun(
    string EvidenceId,
    string OperationId,
    string ToolName,
    string BackendId,
    string BackendMetadataJson,
    EvidenceRequestSpec Request,
    bool DurableStarted,
    long StartedEpochMs,
    string? PreSourceStateId,
    string? PreProjectContextDigest,
    bool BlockedBeforeDispatch,
    string? BlockReason);

internal sealed class EvidenceCoordinator
{
    public const string MetadataSchemaVersion = "1.0.0";
    private readonly EvidenceStore _store;
    private readonly LocalTools _tools;
    private readonly ServerPolicy _policy;
    private readonly string _workspaceFingerprint;
    private readonly Action<string> _log;

    public EvidenceCoordinator(EvidenceStore store, LocalTools tools, ServerPolicy policy, string workspaceFingerprint, Action<string> log)
    {
        _store = store;
        _tools = tools;
        _policy = policy;
        _workspaceFingerprint = workspaceFingerprint;
        _log = log;
    }

    public async Task<EvidenceRun?> BeginAsync(EvidenceRequestSpec? request, string operationId, string toolName)
    {
        if (request is null) return null;
        var evidenceId = EvidenceStore.NewEvidenceId();
        var started = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var backendIdentity = _tools.EvidenceBackendIdentity(toolName);
        var backendId = backendIdentity.BackendId;
        var backendMetadataJson = backendIdentity.ToCanonicalJson();
        var policy = _policy.Capture();
        var durable = true;
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
            await _store.BeginAsync(new EvidenceBegin(
                evidenceId,
                operationId,
                _workspaceFingerprint,
                toolName,
                request.CriterionId,
                started,
                backendId,
                backendMetadataJson,
                policy.Generation,
                policy.Hash,
                CanonicalToolCatalog.CatalogHash,
                CanonicalToolCatalog.CatalogVersion), cts.Token).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            durable = false;
            _log($"[Evidence] durable begin unavailable: {ex.GetType().Name}\n");
        }

        string? preSourceStateId = null;
        string? preContextDigest = null;
        var preFreshnessAvailable = true;
        if (request.CriterionId == "process.exit_zero" && request.RepoPath is not null)
        {
            try
            {
                using var sourceCts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                var source = await _tools.CaptureSourceStateRefAsync(request.RepoPath, request.RelevantPaths, sourceCts.Token).ConfigureAwait(false);
                preSourceStateId = source["source_state_id"]?.GetValue<string>()
                    ?? throw new FileMcpException("Pre-execution SourceStateRef identity is unavailable");
                preContextDigest = _tools.CaptureProjectContextDigest(request.RepoPath);
            }
            catch (Exception ex)
            {
                preFreshnessAvailable = false;
                _log($"[Evidence] pre-execution freshness unavailable: {ex.GetType().Name}\n");
            }
        }

        var blocked = request.Required && (!durable || !preFreshnessAvailable);
        var reason = !durable ? "durable_store_unavailable" : !preFreshnessAvailable ? "freshness_precondition_unavailable" : null;
        return new EvidenceRun(
            evidenceId,
            operationId,
            toolName,
            backendId,
            backendMetadataJson,
            request,
            durable,
            started,
            preSourceStateId,
            preContextDigest,
            blocked,
            reason);
    }

    public async Task<JsonObject?> CompleteAsync(
        EvidenceRun? run,
        bool isError,
        JsonObject? structuredContent,
        ToolExecutionContext? executionContext)
    {
        if (run is null) return null;

        var evaluation = run.BlockedBeforeDispatch
            ? new EvidenceEvaluation("not-run", "blocked", null, false, false, false)
            : EvidenceEvaluator.Evaluate(run.ToolName, run.Request.CriterionId, isError, structuredContent, executionContext);

        JsonObject? sourceState = null;
        string? projectContextDigest = null;
        var sourceBinding = run.Request.RepoPath is null ? "none" : "current";
        if (!run.BlockedBeforeDispatch && run.Request.RepoPath is not null)
        {
            try
            {
                using var sourceCts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                sourceState = await _tools.CaptureSourceStateRefAsync(run.Request.RepoPath, run.Request.RelevantPaths, sourceCts.Token).ConfigureAwait(false);
                projectContextDigest = _tools.CaptureProjectContextDigest(run.Request.RepoPath);
            }
            catch (Exception ex)
            {
                sourceBinding = "unavailable";
                _log($"[Evidence] source/context capture unavailable: {ex.GetType().Name}\n");
            }
        }

        var finalPolicy = _policy.Capture();
        var verification = evaluation.VerificationState;
        if (verification == "passed" && sourceBinding == "unavailable") verification = "unknown";
        if (verification == "passed" && run.Request.CriterionId == "process.exit_zero" && run.Request.RepoPath is not null)
        {
            var postSourceStateId = sourceState?["source_state_id"]?.GetValue<string>();
            if (run.PreSourceStateId is null || run.PreProjectContextDigest is null || postSourceStateId is null || projectContextDigest is null)
            {
                verification = "unknown";
            }
            else if (!string.Equals(run.PreSourceStateId, postSourceStateId, StringComparison.Ordinal) ||
                     !string.Equals(run.PreProjectContextDigest, projectContextDigest, StringComparison.Ordinal))
            {
                verification = "stale";
            }
        }

        var durable = run.DurableStarted;
        if (durable)
        {
            try
            {
                using var storeCts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                await _store.CompleteAsync(new EvidenceCompletion(
                    run.EvidenceId,
                    DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    evaluation.OperationState,
                    verification,
                    sourceState?.ToJsonString(),
                    sourceState?["source_state_id"]?.GetValue<string>(),
                    projectContextDigest,
                    finalPolicy.Generation,
                    finalPolicy.Hash,
                    CanonicalToolCatalog.CatalogHash,
                    CanonicalToolCatalog.CatalogVersion,
                    evaluation.ExitCode,
                    evaluation.TimedOut,
                    evaluation.Cancelled,
                    evaluation.Truncated), storeCts.Token).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                durable = false;
                if (verification is "passed" or "failed" or "stale") verification = "unknown";
                _log($"[Evidence] durable completion unavailable: {ex.GetType().Name}\n");
            }
        }
        else if (verification is "passed" or "failed" or "stale")
        {
            verification = "unknown";
        }

        var metadata = new JsonObject
        {
            ["schema_version"] = MetadataSchemaVersion,
            ["evidence_id"] = run.EvidenceId,
            ["operation_id"] = run.OperationId,
            ["storage_status"] = durable ? "durable" : "unavailable",
            ["operation_state"] = evaluation.OperationState,
            ["verification_state"] = verification,
            ["criterion_id"] = run.Request.CriterionId,
            ["backend_id"] = run.BackendId,
            ["backend_metadata"] = JsonNode.Parse(run.BackendMetadataJson),
            ["source_binding"] = sourceBinding,
            ["source_state_id"] = sourceState?["source_state_id"]?.DeepClone(),
            ["project_context_digest"] = projectContextDigest,
            ["policy_generation"] = finalPolicy.Generation,
            ["policy_hash"] = finalPolicy.Hash,
            ["catalog_hash"] = CanonicalToolCatalog.CatalogHash,
            ["catalog_version"] = CanonicalToolCatalog.CatalogVersion,
            ["block_reason"] = run.BlockReason,
        };
        _log("[EvidenceResult] " + metadata.ToJsonString() + "\n");
        return metadata;
    }

    public async Task<JsonObject> StatusAsync(
        string evidenceId,
        string? repoPath,
        IReadOnlyList<string> relevantPaths,
        CancellationToken cancellationToken = default)
    {
        var record = await _store.GetAsync(evidenceId, cancellationToken).ConfigureAwait(false)
            ?? throw new FileMcpException("Evidence record not found");
        if (!string.Equals(record.WorkspaceFingerprint, _workspaceFingerprint, StringComparison.Ordinal))
            throw new FileMcpException("Evidence record not found");

        var policy = _policy.Capture();
        var freshness = "current";
        var freshnessReason = "none";
        if (!string.Equals(record.CatalogHash, CanonicalToolCatalog.CatalogHash, StringComparison.Ordinal) ||
            !string.Equals(record.CatalogVersion, CanonicalToolCatalog.CatalogVersion, StringComparison.Ordinal) ||
            record.PolicyGeneration != policy.Generation || !string.Equals(record.PolicyHash, policy.Hash, StringComparison.Ordinal))
        {
            freshness = "stale";
            freshnessReason = "policy_or_catalog_changed";
        }

        string? currentSourceStateId = null;
        string? currentProjectContextDigest = null;
        if (record.SourceStateId is not null || record.ProjectContextDigest is not null)
        {
            if (string.IsNullOrWhiteSpace(repoPath))
            {
                if (freshness != "stale")
                {
                    freshness = "unknown";
                    freshnessReason = "source_scope_required";
                }
            }
            else
            {
                try
                {
                    var current = await _tools.CaptureSourceStateRefAsync(repoPath, relevantPaths, cancellationToken).ConfigureAwait(false);
                    currentSourceStateId = current["source_state_id"]?.GetValue<string>();
                    currentProjectContextDigest = _tools.CaptureProjectContextDigest(repoPath);
                    if ((record.SourceStateId is not null && !string.Equals(record.SourceStateId, currentSourceStateId, StringComparison.Ordinal)) ||
                        (record.ProjectContextDigest is not null && !string.Equals(record.ProjectContextDigest, currentProjectContextDigest, StringComparison.Ordinal)))
                    {
                        freshness = "stale";
                        freshnessReason = "source_or_context_changed";
                    }
                }
                catch
                {
                    if (freshness != "stale")
                    {
                        freshness = "unknown";
                        freshnessReason = "source_recompute_failed";
                    }
                }
            }
        }

        var effectiveVerification = record.VerificationState;
        if (record.OperationState == "unknown") effectiveVerification = "unknown";
        else if (freshness == "stale" && effectiveVerification is "passed" or "failed") effectiveVerification = "stale";
        else if (freshness == "unknown" && effectiveVerification is "passed" or "failed") effectiveVerification = "unknown";

        return new JsonObject
        {
            ["schema_version"] = MetadataSchemaVersion,
            ["evidence_id"] = record.EvidenceId,
            ["operation_id"] = record.OperationId,
            ["tool_name"] = record.ToolName,
            ["criterion_id"] = record.CriterionId,
            ["operation_state"] = record.OperationState,
            ["persisted_verification_state"] = record.VerificationState,
            ["verification_state"] = effectiveVerification,
            ["freshness_state"] = freshness,
            ["freshness_reason"] = freshnessReason,
            ["source_state_id"] = record.SourceStateId,
            ["current_source_state_id"] = currentSourceStateId,
            ["project_context_digest"] = record.ProjectContextDigest,
            ["current_project_context_digest"] = currentProjectContextDigest,
            ["policy_generation"] = record.PolicyGeneration,
            ["policy_hash"] = record.PolicyHash,
            ["catalog_hash"] = record.CatalogHash,
            ["catalog_version"] = record.CatalogVersion,
            ["backend_id"] = record.BackendId,
            ["backend_metadata"] = JsonNode.Parse(record.BackendMetadataJson),
            ["exit_code"] = record.ExitCode,
            ["timed_out"] = record.TimedOut,
            ["cancelled"] = record.Cancelled,
            ["truncated"] = record.Truncated,
            ["started_epoch_ms"] = record.StartedEpochMs,
            ["ended_epoch_ms"] = record.EndedEpochMs,
        };
    }
}
