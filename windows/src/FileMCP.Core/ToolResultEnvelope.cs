using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal static class ToolResultEnvelope
{
    public const string MetadataKey = "io.filemcp/result";
    public const string SchemaVersion = "1.0.0";
    private static readonly HashSet<string> Statuses = new(StringComparer.Ordinal) { "success", "partial", "tool_error" };
    private static readonly HashSet<string> TruncationReasons = new(StringComparer.Ordinal) { "none", "server_limit", "output_limit", "unknown" };

    public static JsonObject Create(
        bool isError,
        JsonArray content,
        JsonObject? structuredContent = null,
        IEnumerable<string>? warnings = null,
        JsonObject? usage = null,
        bool forceTruncated = false,
        string? truncationDetail = null)
    {
        var warningArray = new JsonArray();
        if (warnings is not null)
            foreach (var warning in warnings) warningArray.Add(warning);

        var structuredTruncated = structuredContent?["truncated"] is JsonValue truncatedNode &&
            truncatedNode.TryGetValue<bool>(out var isTruncated) && isTruncated;
        var truncated = forceTruncated || structuredTruncated;
        var status = isError ? "tool_error" : truncated ? "partial" : "success";

        var truncation = new JsonObject
        {
            ["truncated"] = truncated,
            ["reason"] = truncated ? "server_limit" : "none",
        };
        if (truncated && !string.IsNullOrWhiteSpace(truncationDetail))
            truncation["detail"] = truncationDetail;

        var usageObject = new JsonObject { ["contentItems"] = content.Count };
        if (usage is not null)
        {
            foreach (var pair in usage)
            {
                if (pair.Key == "contentItems") continue;
                usageObject[pair.Key] = pair.Value?.DeepClone();
            }
        }

        var envelope = new JsonObject
        {
            ["schemaVersion"] = SchemaVersion,
            ["status"] = status,
            ["operationId"] = "op_" + Guid.NewGuid().ToString("N"),
            ["truncation"] = truncation,
            ["usage"] = usageObject,
            ["warnings"] = warningArray,
        };
        Validate(envelope);
        return envelope;
    }

    public static void Attach(
        JsonObject result,
        bool isError,
        JsonArray content,
        JsonObject? structuredContent = null,
        IEnumerable<string>? warnings = null,
        JsonObject? usage = null,
        bool forceTruncated = false,
        string? truncationDetail = null)
    {
        var meta = result["_meta"] as JsonObject ?? new JsonObject();
        meta[MetadataKey] = Create(isError, content, structuredContent, warnings, usage, forceTruncated, truncationDetail);
        result["_meta"] = meta;
    }

    internal static JsonObject Require(JsonObject result)
    {
        if (result["_meta"] is not JsonObject meta || meta[MetadataKey] is not JsonObject envelope)
            throw new FileMcpException("Missing tool result envelope metadata");
        Validate(envelope);
        return envelope;
    }

    internal static void Validate(JsonObject envelope)
    {
        if (envelope["schemaVersion"]?.GetValue<string>() != SchemaVersion)
            throw new FileMcpException("Unknown tool result envelope schemaVersion");

        var status = envelope["status"]?.GetValue<string>();
        if (status is null || !Statuses.Contains(status))
            throw new FileMcpException("Unknown tool result envelope status");

        if (envelope["operationId"] is not JsonValue operationNode || !operationNode.TryGetValue<string>(out var operationId) ||
            !IsOperationId(operationId))
            throw new FileMcpException("Malformed tool result envelope operationId");

        if (envelope["truncation"] is not JsonObject truncation ||
            truncation["truncated"] is not JsonValue truncatedNode || !truncatedNode.TryGetValue<bool>(out var truncated) ||
            truncation["reason"] is not JsonValue reasonNode || !reasonNode.TryGetValue<string>(out var reason) || !TruncationReasons.Contains(reason))
            throw new FileMcpException("Malformed tool result envelope truncation");
        if ((!truncated && reason != "none") || (truncated && reason == "none"))
            throw new FileMcpException("Inconsistent tool result envelope truncation");
        if (truncation["detail"] is JsonNode detailNode &&
            (detailNode is not JsonValue detailValue || !detailValue.TryGetValue<string>(out var detail) ||
             string.IsNullOrWhiteSpace(detail) || detail.Length > 64))
            throw new FileMcpException("Malformed tool result envelope truncation detail");
        if (status == "partial" && !truncated)
            throw new FileMcpException("Partial tool result envelope must be truncated");
        if (status == "success" && truncated)
            throw new FileMcpException("Successful tool result envelope cannot be truncated");

        if (envelope["usage"] is not JsonObject usage ||
            usage["contentItems"] is not JsonValue itemsNode || !itemsNode.TryGetValue<int>(out var items) || items < 0)
            throw new FileMcpException("Malformed tool result envelope usage");

        foreach (var key in new[] { "visitedEntries", "filesScanned", "outputItems" })
        {
            if (usage[key] is JsonNode node &&
                (node is not JsonValue value || !value.TryGetValue<int>(out var count) || count < 0))
                throw new FileMcpException($"Malformed tool result envelope usage field: {key}");
        }
        if (usage["bytesScanned"] is JsonNode bytesNode &&
            (bytesNode is not JsonValue bytesValue || !bytesValue.TryGetValue<long>(out var bytes) || bytes < 0))
            throw new FileMcpException("Malformed tool result envelope usage field: bytesScanned");
        if (usage["truncated"] is JsonNode usageTruncatedNode &&
            (usageTruncatedNode is not JsonValue usageTruncatedValue || !usageTruncatedValue.TryGetValue<bool>(out _)))
            throw new FileMcpException("Malformed tool result envelope usage field: truncated");
        if (usage["truncationReason"] is JsonNode usageReasonNode &&
            (usageReasonNode is not JsonValue usageReasonValue || !usageReasonValue.TryGetValue<string>(out var usageReason) ||
             string.IsNullOrWhiteSpace(usageReason) || usageReason.Length > 64))
            throw new FileMcpException("Malformed tool result envelope usage field: truncationReason");

        if (envelope["warnings"] is not JsonArray warnings || warnings.Any(node =>
                node is not JsonValue value || !value.TryGetValue<string>(out var warning) || string.IsNullOrWhiteSpace(warning)))
            throw new FileMcpException("Malformed tool result envelope warnings");
    }

    private static bool IsOperationId(string value)
    {
        if (!value.StartsWith("op_", StringComparison.Ordinal) || value.Length != 35) return false;
        return value.AsSpan(3).ToArray().All(ch => ch is >= '0' and <= '9' or >= 'a' and <= 'f');
    }
}
