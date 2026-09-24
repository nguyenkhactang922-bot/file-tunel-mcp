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
        IEnumerable<string>? warnings = null)
    {
        var warningArray = new JsonArray();
        if (warnings is not null)
            foreach (var warning in warnings) warningArray.Add(warning);

        var truncated = structuredContent?["truncated"] is JsonValue truncatedNode &&
            truncatedNode.TryGetValue<bool>(out var isTruncated) && isTruncated;
        var status = isError ? "tool_error" : truncated ? "partial" : "success";
        var envelope = new JsonObject
        {
            ["schemaVersion"] = SchemaVersion,
            ["status"] = status,
            ["operationId"] = "op_" + Guid.NewGuid().ToString("N"),
            ["truncation"] = new JsonObject
            {
                ["truncated"] = truncated,
                ["reason"] = truncated ? "server_limit" : "none",
            },
            ["usage"] = new JsonObject { ["contentItems"] = content.Count },
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
        IEnumerable<string>? warnings = null)
    {
        var meta = result["_meta"] as JsonObject ?? new JsonObject();
        meta[MetadataKey] = Create(isError, content, structuredContent, warnings);
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
        if (status == "partial" && !truncated)
            throw new FileMcpException("Partial tool result envelope must be truncated");
        if (status == "success" && truncated)
            throw new FileMcpException("Successful tool result envelope cannot be truncated");

        if (envelope["usage"] is not JsonObject usage ||
            usage["contentItems"] is not JsonValue itemsNode || !itemsNode.TryGetValue<int>(out var items) || items < 0)
            throw new FileMcpException("Malformed tool result envelope usage");

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
