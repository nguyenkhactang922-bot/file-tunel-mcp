using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FileMCP.Core;


internal sealed record ToolPolicyMetadata(
    string Name,
    string Risk,
    string Effect,
    IReadOnlyList<string> Capabilities,
    bool RequiresCommands,
    bool RequiresObservability);

internal static class CanonicalToolCatalog
{
    private const string ResourceName = "FileMCP.Contracts.tool_catalog.v1.json";
    private const int SupportedSchemaVersion = 1;
    private const string SupportedCatalogVersion = "1.0.0";
    private const string SupportedInstructionVersion = "1.0.0";
    private static readonly HashSet<string> SupportedRisks = new(new[] { "low", "medium", "high" }, StringComparer.Ordinal);
    private static readonly HashSet<string> SupportedEffects = new(new[] { "read", "write", "delete", "execute", "external", "metadata" }, StringComparer.Ordinal);
    private static readonly HashSet<string> SupportedHandlers = new(new[] { "local_tools", "skills", "server" }, StringComparer.Ordinal);
    private static readonly HashSet<string> SupportedAvailabilityKeys = new(new[] { "requiresCommands", "requiresObservability" }, StringComparer.Ordinal);
    private static readonly Lazy<CatalogState> State = new(Load, LazyThreadSafetyMode.ExecutionAndPublication);

    public static string CatalogVersion => State.Value.CatalogVersion;
    public static string CatalogHash => State.Value.CatalogHash;
    public static string InstructionVersion => State.Value.InstructionVersion;
    public static string InstructionHash => State.Value.InstructionHash;
    public static string ModernProtocolVersion => State.Value.ModernProtocolVersion;
    public static IReadOnlyList<string> LegacyProtocolVersions => State.Value.LegacyProtocolVersions;
    public static string BaseInstructions => State.Value.BaseInstructions;
    public static string ObservabilityInstructionsSuffix => State.Value.ObservabilityInstructionsSuffix;
    public static string CorrelationArgumentName => State.Value.CorrelationArgumentName;

    public static JsonObject CorrelationArgumentDefinition() => (JsonObject)State.Value.CorrelationArgumentDefinition.DeepClone();

    public static string Instructions(bool includeObservability) =>
        includeObservability ? ComposeInstructions(BaseInstructions, ObservabilityInstructionsSuffix) : BaseInstructions;

    public static JsonObject Metadata(string buildIdentity) => new()
    {
        ["catalogVersion"] = CatalogVersion,
        ["catalogHash"] = CatalogHash,
        ["instructionVersion"] = InstructionVersion,
        ["instructionHash"] = InstructionHash,
        ["buildIdentity"] = buildIdentity,
    };

    public static JsonArray ToolDefinitions(string handler, bool commandsEnabled = true, bool observabilityEnabled = true)
    {
        var result = new JsonArray();
        foreach (var entry in State.Value.Tools)
        {
            if (!string.Equals(entry.Handler, handler, StringComparison.Ordinal)) continue;
            if (entry.RequiresCommands && !commandsEnabled) continue;
            if (entry.RequiresObservability && !observabilityEnabled) continue;
            result.Add(entry.Definition.DeepClone());
        }
        return result;
    }

    public static JsonObject ToolDefinition(string name)
    {
        var match = State.Value.Tools.FirstOrDefault(tool => string.Equals(tool.Name, name, StringComparison.Ordinal));
        return match is null
            ? throw new FileMcpException($"Canonical tool catalog is missing tool: {name}")
            : (JsonObject)match.Definition.DeepClone();
    }

    public static ToolPolicyMetadata ToolPolicyMetadata(string name)
    {
        var match = State.Value.Tools.FirstOrDefault(tool => string.Equals(tool.Name, name, StringComparison.Ordinal));
        return match is null
            ? throw new FileMcpException($"Canonical tool catalog is missing tool: {name}")
            : new ToolPolicyMetadata(match.Name, match.Risk, match.Effect, match.Capabilities, match.RequiresCommands, match.RequiresObservability);
    }

    public static bool ContainsTool(string name) => State.Value.Tools.Any(tool => string.Equals(tool.Name, name, StringComparison.Ordinal));

    public static void ValidateHandlerCoverage(string handler, IEnumerable<string> runtimeHandlerNames)
    {
        var expected = State.Value.Tools.Where(tool => tool.Handler == handler).Select(tool => tool.Name).ToHashSet(StringComparer.Ordinal);
        var actual = runtimeHandlerNames.ToHashSet(StringComparer.Ordinal);
        var missing = expected.Except(actual, StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
        var extra = actual.Except(expected, StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
        if (missing.Length == 0 && extra.Length == 0) return;
        throw new FileMcpException($"Canonical tool handler coverage mismatch for '{handler}': missing=[{string.Join(',', missing)}] extra=[{string.Join(',', extra)}]");
    }

    public static void ValidateProtocolContract(string modern, IEnumerable<string> legacy)
    {
        if (!string.Equals(modern, ModernProtocolVersion, StringComparison.Ordinal))
            throw new FileMcpException($"Canonical catalog modern protocol mismatch: runtime={modern} catalog={ModernProtocolVersion}");
        var runtimeLegacy = legacy.ToHashSet(StringComparer.Ordinal);
        var catalogLegacy = LegacyProtocolVersions.ToHashSet(StringComparer.Ordinal);
        if (!runtimeLegacy.SetEquals(catalogLegacy))
            throw new FileMcpException("Canonical catalog legacy protocol set does not match runtime protocol constants");
    }

    private static CatalogState Load()
    {
        using var stream = typeof(CanonicalToolCatalog).Assembly.GetManifestResourceStream(ResourceName)
            ?? throw new FileMcpException($"Embedded canonical tool catalog resource is missing: {ResourceName}");
        using var memory = new MemoryStream();
        stream.CopyTo(memory);
        return Parse(memory.ToArray());
    }

    internal static void ValidateCatalogPayloadForTest(string payload) =>
        _ = Parse(Encoding.UTF8.GetBytes(payload));

    internal static string CatalogHashForPayloadForTest(string payload) =>
        Parse(Encoding.UTF8.GetBytes(payload)).CatalogHash;

    private static CatalogState Parse(byte[] bytes)
    {
        var text = Encoding.UTF8.GetString(bytes);
        JsonObject root;
        try
        {
            root = JsonNode.Parse(text) as JsonObject
                ?? throw new FileMcpException("Canonical tool catalog root must be a JSON object");
        }
        catch (JsonException ex)
        {
            throw new FileMcpException($"Malformed canonical tool catalog JSON: {ex.Message}");
        }

        var schemaVersion = RequiredInt(root, "schemaVersion");
        if (schemaVersion != SupportedSchemaVersion)
            throw new FileMcpException($"Unsupported canonical tool catalog schemaVersion: {schemaVersion}");
        var catalogVersion = RequiredString(root, "catalogVersion");
        if (!string.Equals(catalogVersion, SupportedCatalogVersion, StringComparison.Ordinal))
            throw new FileMcpException($"Unsupported canonical tool catalog catalogVersion: {catalogVersion}");
        var instructionVersion = RequiredString(root, "instructionVersion");
        if (!string.Equals(instructionVersion, SupportedInstructionVersion, StringComparison.Ordinal))
            throw new FileMcpException($"Unsupported canonical tool catalog instructionVersion: {instructionVersion}");
        var protocols = RequiredObject(root, "protocolVersions");
        var modern = RequiredString(protocols, "modern");
        var legacy = RequiredStringArray(protocols, "legacy");
        var instructions = RequiredObject(root, "instructions");
        var baseInstructions = RequiredString(instructions, "base");
        var observabilitySuffix = RequiredString(instructions, "observabilitySuffix");
        var facades = RequiredObject(root, "facades");
        var correlation = RequiredObject(facades, "correlationArgument");
        var correlationName = RequiredString(correlation, "name");
        var correlationDefinition = RequiredObject(correlation, "definition");
        var toolArray = root["tools"] as JsonArray ?? throw new FileMcpException("Canonical tool catalog tools must be an array");
        if (toolArray.Count == 0) throw new FileMcpException("Canonical tool catalog must contain tools");

        var tools = new List<CatalogTool>(toolArray.Count);
        var names = new HashSet<string>(StringComparer.Ordinal);
        foreach (var node in toolArray)
        {
            var item = node as JsonObject ?? throw new FileMcpException("Canonical tool catalog tool entry must be an object");
            var name = RequiredString(item, "name");
            if (!names.Add(name)) throw new FileMcpException($"Duplicate canonical tool name: {name}");
            var handler = RequiredString(item, "handler");
            if (!SupportedHandlers.Contains(handler))
                throw new FileMcpException($"Unsupported canonical tool handler metadata for {name}: {handler}");
            var risk = RequiredString(item, "risk");
            if (!SupportedRisks.Contains(risk))
                throw new FileMcpException($"Unsupported canonical tool risk metadata for {name}: {risk}");
            var effect = RequiredString(item, "effect");
            if (!SupportedEffects.Contains(effect))
                throw new FileMcpException($"Unsupported canonical tool effect metadata for {name}: {effect}");
            var capabilities = RequiredStringArray(item, "capabilities");
            if (capabilities.Count == 0)
                throw new FileMcpException($"Canonical tool capabilities must not be empty for {name}");
            var availability = RequiredObject(item, "availability");
            foreach (var pair in availability)
            {
                if (!SupportedAvailabilityKeys.Contains(pair.Key) || pair.Value is not JsonValue availabilityValue || !availabilityValue.TryGetValue<bool>(out _))
                    throw new FileMcpException($"Unsupported canonical tool availability metadata for {name}: {pair.Key}");
            }
            var requiresCommands = OptionalBool(availability, "requiresCommands");
            var requiresObservability = OptionalBool(availability, "requiresObservability");
            var definition = RequiredObject(item, "definition");
            if (!string.Equals(RequiredString(definition, "name"), name, StringComparison.Ordinal))
                throw new FileMcpException($"Canonical definition name mismatch for {name}");
            _ = RequiredObject(definition, "inputSchema");
            _ = RequiredObject(definition, "outputSchema");
            _ = RequiredObject(definition, "annotations");
            tools.Add(new CatalogTool(name, handler, risk, effect, capabilities, requiresCommands, requiresObservability, (JsonObject)definition.DeepClone()));
        }

        return new CatalogState(
            catalogVersion,
            Sha256Hex(Encoding.UTF8.GetBytes(NormalizeCatalogText(text))),
            instructionVersion,
            Sha256Hex(Encoding.UTF8.GetBytes(ComposeInstructions(baseInstructions, observabilitySuffix))),
            modern,
            legacy,
            baseInstructions,
            observabilitySuffix,
            correlationName,
            (JsonObject)correlationDefinition.DeepClone(),
            tools);
    }

    private static string RequiredString(JsonObject obj, string key) =>
        obj[key] is JsonValue value && value.TryGetValue<string>(out var result) && !string.IsNullOrWhiteSpace(result)
            ? result
            : throw new FileMcpException($"Canonical tool catalog field '{key}' must be a non-empty string");

    private static int RequiredInt(JsonObject obj, string key) =>
        obj[key] is JsonValue value && value.TryGetValue<int>(out var result)
            ? result
            : throw new FileMcpException($"Canonical tool catalog field '{key}' must be an integer");

    private static JsonObject RequiredObject(JsonObject obj, string key) =>
        obj[key] as JsonObject ?? throw new FileMcpException($"Canonical tool catalog field '{key}' must be an object");

    private static IReadOnlyList<string> RequiredStringArray(JsonObject obj, string key)
    {
        var array = obj[key] as JsonArray ?? throw new FileMcpException($"Canonical tool catalog field '{key}' must be an array");
        return array.Select((node, index) =>
            node is JsonValue value && value.TryGetValue<string>(out var text) && !string.IsNullOrWhiteSpace(text)
                ? text
                : throw new FileMcpException($"Canonical tool catalog field '{key}[{index}]' must be a non-empty string")).ToArray();
    }

    private static bool OptionalBool(JsonObject obj, string key)
    {
        if (obj[key] is null) return false;
        return obj[key] is JsonValue value && value.TryGetValue<bool>(out var result)
            ? result
            : throw new FileMcpException($"Canonical tool catalog field '{key}' must be boolean when present");
    }

    private static string ComposeInstructions(string baseInstructions, string observabilitySuffix) =>
        baseInstructions + observabilitySuffix;

    private static string NormalizeCatalogText(string text)
    {
        if (text.Length > 0 && text[0] == '\ufeff') text = text[1..];
        return text.Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n');
    }

    private static string Sha256Hex(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();

    private sealed record CatalogTool(string Name, string Handler, string Risk, string Effect, IReadOnlyList<string> Capabilities, bool RequiresCommands, bool RequiresObservability, JsonObject Definition);
    private sealed record CatalogState(
        string CatalogVersion,
        string CatalogHash,
        string InstructionVersion,
        string InstructionHash,
        string ModernProtocolVersion,
        IReadOnlyList<string> LegacyProtocolVersions,
        string BaseInstructions,
        string ObservabilityInstructionsSuffix,
        string CorrelationArgumentName,
        JsonObject CorrelationArgumentDefinition,
        IReadOnlyList<CatalogTool> Tools);
}