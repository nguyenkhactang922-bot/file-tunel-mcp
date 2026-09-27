using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed record EvidenceRequestSpec(string CriterionId, string? RepoPath, IReadOnlyList<string> RelevantPaths, bool Required)
{
    public const string MetadataKey = "io.filemcp/evidence";
    private static readonly HashSet<string> AllowedCriteria = new(StringComparer.Ordinal)
    {
        "tool.success", "process.exit_zero",
    };

    public static EvidenceRequestSpec? Parse(JsonObject? meta, string toolName)
    {
        if (meta?[MetadataKey] is null) return null;
        if (meta[MetadataKey] is not JsonObject evidence)
            throw new FileMcpException($"{MetadataKey} must be an object");
        foreach (var key in evidence.Select(pair => pair.Key))
            if (key is not ("criterionId" or "repoPath" or "relevantPaths" or "required"))
                throw new FileMcpException($"Unknown evidence metadata field: {key}");

        if (evidence["criterionId"] is not JsonValue criterionValue ||
            !criterionValue.TryGetValue<string>(out var criterion) ||
            string.IsNullOrWhiteSpace(criterion) || !AllowedCriteria.Contains(criterion))
            throw new FileMcpException("Evidence criterionId must be one of the supported server-owned criteria");
        if (criterion == "process.exit_zero" && toolName != "exec_process")
            throw new FileMcpException("process.exit_zero evidence is only supported for exec_process");

        string? repoPath = null;
        if (evidence["repoPath"] is JsonNode repoNode)
        {
            if (repoNode is not JsonValue repoValue || !repoValue.TryGetValue<string>(out repoPath) ||
                string.IsNullOrWhiteSpace(repoPath) || repoPath.Length > 4096)
                throw new FileMcpException("Evidence repoPath must be a non-empty bounded string");
        }

        var relevantPaths = new List<string>();
        if (evidence["relevantPaths"] is JsonNode relevantNode)
        {
            if (relevantNode is not JsonArray array || array.Count > 4096)
                throw new FileMcpException("Evidence relevantPaths supports at most 4096 paths");
            foreach (var node in array)
            {
                if (node is not JsonValue value || !value.TryGetValue<string>(out var path) ||
                    string.IsNullOrWhiteSpace(path) || path.Length > 4096)
                    throw new FileMcpException("Evidence relevantPaths entries must be non-empty bounded strings");
                relevantPaths.Add(path);
            }
            if (repoPath is null && relevantPaths.Count > 0)
                throw new FileMcpException("Evidence relevantPaths requires repoPath");
        }
        var required = false;
        if (evidence["required"] is JsonNode requiredNode)
        {
            if (requiredNode is not JsonValue requiredValue || !requiredValue.TryGetValue<bool>(out required))
                throw new FileMcpException("Evidence required must be a boolean");
        }
        return new EvidenceRequestSpec(criterion, repoPath, relevantPaths, required);
    }
}

internal sealed record EvidenceEvaluation(
    string OperationState,
    string VerificationState,
    int? ExitCode,
    bool TimedOut,
    bool Cancelled,
    bool Truncated);

internal static class EvidenceEvaluator
{
    public static EvidenceEvaluation Evaluate(
        string toolName,
        string? criterionId,
        bool isError,
        JsonObject? structuredContent,
        ToolExecutionContext? executionContext)
    {
        int? exitCode = null;
        if (structuredContent?["exit_code"] is JsonValue exitNode && exitNode.TryGetValue<int>(out var parsedExit)) exitCode = parsedExit;
        var timedOut = TryBool(structuredContent, "timed_out");
        var cancelled = TryBool(structuredContent, "cancelled") || executionContext?.CancellationRequested == true;
        var truncated = executionContext?.Truncated == true || TryBool(structuredContent, "truncated") ||
            TryBool(structuredContent, "stdout_truncated") || TryBool(structuredContent, "stderr_truncated");

        var operationState = timedOut ? "timed_out" : cancelled ? "cancelled" : isError ? "failed" : "succeeded";
        var verification = criterionId switch
        {
            null => "not-run",
            "tool.success" => isError ? "failed" : "passed",
            "process.exit_zero" when toolName == "exec_process" && (timedOut || cancelled) => "unknown",
            "process.exit_zero" when toolName == "exec_process" && exitCode.HasValue && exitCode.Value != 0 => "failed",
            "process.exit_zero" when toolName == "exec_process" && exitCode.HasValue && !isError => "passed",
            "process.exit_zero" => "unknown",
            _ => "unknown",
        };
        return new EvidenceEvaluation(operationState, verification, exitCode, timedOut, cancelled, truncated);
    }

    private static bool TryBool(JsonObject? source, string key) =>
        source?[key] is JsonValue value && value.TryGetValue<bool>(out var result) && result;
}
