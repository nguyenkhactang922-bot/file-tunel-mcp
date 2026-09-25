using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

public static class FileMcpPolicyProfiles
{
    public const string Restricted = "restricted";
    public const string WorkspaceAuto = "workspace-auto";
    public const string Custom = "custom";
    public const string LegacyCommandCompatible = "legacy-command-compatible";

    public static bool IsKnown(string value) => value is Restricted or WorkspaceAuto or Custom or LegacyCommandCompatible;
    public static bool IsUserSelectable(string value) => value is Restricted or WorkspaceAuto or Custom;
}

public sealed class LocalPolicyConfiguration
{
    public string Profile { get; set; } = FileMcpPolicyProfiles.Restricted;
    public string CustomMaxRisk { get; set; } = "low";
    public List<string> CustomAllowedEffects { get; set; } = ["read", "metadata"];
    public bool CustomAllowNetworkOpenWorld { get; set; }
    public bool CustomAllowShell { get; set; }

    public static LocalPolicyConfiguration FromLegacy(bool enableCommands) => new()
    {
        Profile = enableCommands ? FileMcpPolicyProfiles.LegacyCommandCompatible : FileMcpPolicyProfiles.Restricted,
    };

    public LocalPolicyConfiguration CloneNormalized()
    {
        var profile = string.IsNullOrWhiteSpace(Profile) ? FileMcpPolicyProfiles.Restricted : Profile.Trim().ToLowerInvariant();
        if (!FileMcpPolicyProfiles.IsKnown(profile)) throw new FileMcpException($"Unsupported policy profile: {Profile}");
        var maxRisk = string.IsNullOrWhiteSpace(CustomMaxRisk) ? "low" : CustomMaxRisk.Trim().ToLowerInvariant();
        if (maxRisk is not ("low" or "medium" or "high")) throw new FileMcpException($"Unsupported custom policy risk: {CustomMaxRisk}");
        var effects = (CustomAllowedEffects ?? [])
            .Where(effect => !string.IsNullOrWhiteSpace(effect))
            .Select(effect => effect.Trim().ToLowerInvariant())
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToList();
        var validEffects = new HashSet<string>(new[] { "read", "write", "delete", "execute", "external", "metadata" }, StringComparer.Ordinal);
        if (effects.Any(effect => !validEffects.Contains(effect)))
            throw new FileMcpException("Custom policy contains an unsupported effect");
        return new LocalPolicyConfiguration
        {
            Profile = profile,
            CustomMaxRisk = maxRisk,
            CustomAllowedEffects = effects,
            CustomAllowNetworkOpenWorld = CustomAllowNetworkOpenWorld,
            CustomAllowShell = CustomAllowShell,
        };
    }
}

internal readonly record struct PolicySnapshot(long Generation, string Hash);

internal sealed class ServerPolicy
{
    private sealed record PolicyState(long Generation, string Hash, LocalPolicyConfiguration Configuration);
    private readonly object _gate = new();
    private PolicyState _state;

    public ServerPolicy(LocalPolicyConfiguration configuration)
    {
        var normalized = configuration.CloneNormalized();
        _state = new PolicyState(1, ComputeHash(normalized), normalized);
    }

    public static ServerPolicy FromLegacy(bool enableCommands) => new(LocalPolicyConfiguration.FromLegacy(enableCommands));

    public string Profile { get { lock (_gate) return _state.Configuration.Profile; } }
    public long Generation { get { lock (_gate) return _state.Generation; } }
    public string Hash { get { lock (_gate) return _state.Hash; } }
    public bool LegacyUnsafeGitCompatibility { get { lock (_gate) return _state.Configuration.Profile == FileMcpPolicyProfiles.LegacyCommandCompatible; } }

    public PolicySnapshot Capture()
    {
        lock (_gate) return new PolicySnapshot(_state.Generation, _state.Hash);
    }

    public void Update(LocalPolicyConfiguration configuration)
    {
        var normalized = configuration.CloneNormalized();
        var hash = ComputeHash(normalized);
        lock (_gate)
        {
            if (string.Equals(hash, _state.Hash, StringComparison.Ordinal)) return;
            _state = new PolicyState(checked(_state.Generation + 1), hash, normalized);
        }
    }

    public bool IsAllowed(string toolName)
    {
        var metadata = CanonicalToolCatalog.ToolPolicyMetadata(toolName);
        lock (_gate) return IsAllowed(_state.Configuration, metadata);
    }

    public JsonArray FilterDefinitions(JsonArray definitions)
    {
        var result = new JsonArray();
        foreach (var node in definitions)
        {
            if (node is not JsonObject definition || definition["name"] is not JsonValue value || !value.TryGetValue<string>(out var name))
                throw new FileMcpException("Invalid tool definition while applying policy");
            if (IsAllowed(name)) result.Add(definition.DeepClone());
        }
        return result;
    }

    public void Authorize(string toolName, PolicySnapshot? prepared = null)
    {
        var metadata = CanonicalToolCatalog.ToolPolicyMetadata(toolName);
        lock (_gate)
        {
            if (prepared.HasValue && (prepared.Value.Generation != _state.Generation || !string.Equals(prepared.Value.Hash, _state.Hash, StringComparison.Ordinal)))
                throw new FileMcpException("Prepared operation is stale because local policy changed");
            if (!IsAllowed(_state.Configuration, metadata))
                throw new FileMcpException($"Tool is denied by active local policy: {toolName}");
        }
    }

    public JsonObject Metadata()
    {
        lock (_gate)
        {
            return new JsonObject
            {
                ["profile"] = _state.Configuration.Profile,
                ["generation"] = _state.Generation,
                ["hash"] = _state.Hash,
            };
        }
    }

    private static bool IsAllowed(LocalPolicyConfiguration configuration, ToolPolicyMetadata metadata)
    {
        switch (configuration.Profile)
        {
            case FileMcpPolicyProfiles.Restricted:
                return !metadata.Capabilities.Contains("process.shell", StringComparer.Ordinal) &&
                       !metadata.Capabilities.Contains("process.exec", StringComparer.Ordinal);
            case FileMcpPolicyProfiles.LegacyCommandCompatible:
                return true;
            case FileMcpPolicyProfiles.WorkspaceAuto:
                return !metadata.Capabilities.Contains("process.shell", StringComparer.Ordinal) &&
                       !metadata.Capabilities.Contains("network.open_world", StringComparer.Ordinal) &&
                       metadata.Effect != "external";
            case FileMcpPolicyProfiles.Custom:
                if (RiskRank(metadata.Risk) > RiskRank(configuration.CustomMaxRisk)) return false;
                if (!configuration.CustomAllowedEffects.Contains(metadata.Effect, StringComparer.Ordinal)) return false;
                if (!configuration.CustomAllowNetworkOpenWorld && metadata.Capabilities.Contains("network.open_world", StringComparer.Ordinal)) return false;
                if (!configuration.CustomAllowShell && metadata.Capabilities.Contains("process.shell", StringComparer.Ordinal)) return false;
                return true;
            default:
                return false;
        }
    }

    private static int RiskRank(string value) => value switch { "low" => 0, "medium" => 1, "high" => 2, _ => int.MaxValue };

    private static string ComputeHash(LocalPolicyConfiguration configuration)
    {
        var canonical = string.Join("\n", new[]
        {
            configuration.Profile,
            configuration.CustomMaxRisk,
            string.Join(",", configuration.CustomAllowedEffects),
            configuration.CustomAllowNetworkOpenWorld ? "true" : "false",
            configuration.CustomAllowShell ? "true" : "false",
        });
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
    }
}
