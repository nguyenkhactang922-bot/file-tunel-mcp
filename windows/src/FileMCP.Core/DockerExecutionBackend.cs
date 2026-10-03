using System.Globalization;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace FileMCP.Core;

public sealed class DockerExecutionBackendConfiguration
{
    public bool Enabled { get; set; }
    public string Image { get; set; } = "";
    public List<string> AllowedImages { get; set; } = [];
    public bool NetworkEnabled { get; set; }
    public double CpuLimit { get; set; } = 2.0;
    public long MemoryBytes { get; set; } = 2L * 1024 * 1024 * 1024;
    public int PidsLimit { get; set; } = 128;
    public string User { get; set; } = "1000:1000";
    public int StartupTimeoutSeconds { get; set; } = 30;
    public int IdleTtlSeconds { get; set; } = 900;
    public int MaxLifetimeSeconds { get; set; } = 7200;

    internal DockerExecutionBackendConfiguration CloneNormalized()
    {
        var normalized = new DockerExecutionBackendConfiguration
        {
            Enabled = Enabled,
            Image = (Image ?? "").Trim(),
            AllowedImages = (AllowedImages ?? [])
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Select(value => value.Trim())
                .Distinct(StringComparer.Ordinal)
                .Order(StringComparer.Ordinal)
                .ToList(),
            NetworkEnabled = NetworkEnabled,
            CpuLimit = CpuLimit,
            MemoryBytes = MemoryBytes,
            PidsLimit = PidsLimit,
            User = (User ?? "").Trim(),
            StartupTimeoutSeconds = StartupTimeoutSeconds,
            IdleTtlSeconds = IdleTtlSeconds,
            MaxLifetimeSeconds = MaxLifetimeSeconds,
        };
        DockerExecutionBackend.ValidateConfiguration(normalized);
        return normalized;
    }
}

internal interface IDockerCliRunner
{
    Task<ProcessResult> RunAsync(
        IReadOnlyList<string> arguments,
        IReadOnlyDictionary<string, string> environment,
        int timeoutSeconds,
        int outputLimitBytes,
        CancellationToken cancellationToken);
}

internal sealed class ProcessDockerCliRunner : IDockerCliRunner
{
    public Task<ProcessResult> RunAsync(
        IReadOnlyList<string> arguments,
        IReadOnlyDictionary<string, string> environment,
        int timeoutSeconds,
        int outputLimitBytes,
        CancellationToken cancellationToken) =>
        ProcessRunner.RunAsync(
            "docker",
            arguments,
            environment: environment,
            timeoutSeconds: timeoutSeconds,
            outputLimitBytes: outputLimitBytes,
            cancellationToken: cancellationToken);
}

internal sealed class DockerExecutionBackend : IExecutionBackend
{
    public const string BackendId = "docker-isolated";
    public const string BackendVersion = "1.0.0";
    private const string WorkspaceDestination = "/workspace";
    private const string OwnerLabelKey = "io.filemcp.owner";
    private const string OwnerLabelValue = "filemcp";
    private const string BackendLabelKey = "io.filemcp.backend";
    private const string WorkspaceLabelKey = "io.filemcp.workspace";
    private const string LeaseLabelKey = "io.filemcp.lease";
    private const int DockerControlOutputLimit = 256_000;

    private static readonly Regex DigestPinnedImagePattern = new(
        @"^[^\s@]{1,448}@sha256:[0-9a-f]{64}$",
        RegexOptions.CultureInvariant | RegexOptions.Compiled);
    private static readonly Regex ContainerIdPattern = new(
        @"^[0-9a-f]{12,64}$",
        RegexOptions.CultureInvariant | RegexOptions.Compiled);
    private static readonly Regex UserPattern = new(
        @"^[A-Za-z0-9_.-]{1,64}(?::[A-Za-z0-9_.-]{1,64})?$",
        RegexOptions.CultureInvariant | RegexOptions.Compiled);
    private static readonly string[] DockerControlEnvironmentNames =
    [
        "DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH", "DOCKER_CONFIG",
        "HOME", "USERPROFILE", "HOMEDRIVE", "HOMEPATH", "XDG_CONFIG_HOME",
    ];

    private readonly SafePathResolver _resolver;
    private readonly ExecProcessEnvironmentAuthority _environmentAuthority;
    private readonly ExecProcessEnvironmentAuthority _dockerClientEnvironmentAuthority;
    private readonly ArtifactContentStore _artifactStore;
    private readonly PersistentPtyService _pty;
    private readonly IDockerCliRunner _docker;
    private readonly DockerExecutionBackendConfiguration _configuration;
    private readonly string _workspaceAuthorityId;
    private readonly string _imageDigest;
    private readonly SemaphoreSlim _containerGate = new(1, 1);
    private readonly object _healthGate = new();
    private readonly CancellationTokenSource _maintenanceCts = new();
    private readonly Task _maintenanceTask;
    private string? _containerId;
    private DateTimeOffset? _containerCreatedUtc;
    private DateTimeOffset? _lastActivityUtc;
    private string? _leaseId;
    private bool _disposed;
    private ExecutionBackendHealth _health = new(true, "degraded", "not-probed");

    public DockerExecutionBackend(
        SafePathResolver resolver,
        ExecProcessEnvironmentAuthority environmentAuthority,
        ArtifactContentStore artifactStore,
        DockerExecutionBackendConfiguration configuration,
        bool allowNetworkEnabled,
        IDockerCliRunner? docker = null)
    {
        _resolver = resolver;
        _environmentAuthority = environmentAuthority;
        _artifactStore = artifactStore;
        _configuration = configuration.CloneNormalized();
        if (!_configuration.Enabled)
            throw new FileMcpException("Docker execution backend configuration is not enabled");
        if (_configuration.NetworkEnabled && !allowNetworkEnabled)
            throw new FileMcpException("Docker network-enabled execution requires explicit custom local network policy");

        _workspaceAuthorityId = ArtifactContentStore.WorkspaceAuthorityId(_resolver.Root);
        _imageDigest = _configuration.Image[(_configuration.Image.IndexOf("@", StringComparison.Ordinal) + 1)..];
        _docker = docker ?? new ProcessDockerCliRunner();
        _dockerClientEnvironmentAuthority = new ExecProcessEnvironmentAuthority(
            _environmentAuthority.Patterns,
            blockedOverrideNames: DockerControlEnvironmentNames);
        _pty = new PersistentPtyService(_resolver, _dockerClientEnvironmentAuthority, () => _artifactStore);
        ExecutionBackendContracts.ValidateDescriptor(Descriptor);
        ExecutionBackendContracts.ValidateEvidenceIdentity(EvidenceIdentity);
        _maintenanceTask = Task.Run(() => MaintenanceLoopAsync(_maintenanceCts.Token));
    }

    public ExecutionBackendDescriptor Descriptor => new(
        BackendId,
        BackendVersion,
        BuildCapabilities(),
        WorkspaceMode: "container-mounted",
        EnvironmentMode: "mediated",
        NetworkMode: _configuration.NetworkEnabled ? "bridge" : "none",
        ResourceMode: "container-capped");

    public ExecutionBackendHealth Health
    {
        get { lock (_healthGate) return _disposed ? new(false, "disposed") : _health; }
    }

    public ExecutionBackendEvidenceIdentity EvidenceIdentity => new(
        BackendId,
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["image_digest"] = _imageDigest,
            ["workspace_mode"] = "container-mounted",
            ["network_policy"] = _configuration.NetworkEnabled ? "bridge" : "none",
            ["resource_policy"] = string.Create(
                CultureInfo.InvariantCulture,
                $"cpu={_configuration.CpuLimit:0.###};memory={_configuration.MemoryBytes};pids={_configuration.PidsLimit}"),
        });

    public async Task<ProcessResult> RunProcessAsync(ExecutionProcessRequest request, CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        var containerCwd = ContainerWorkingDirectory(request.Cwd);
        var isolatedEnvironment = BuildContainerEnvironment(request.EnvironmentOverrides);
        var dockerEnvironment = DockerClientEnvironment(request.EnvironmentOverrides);
        var container = await EnsureContainerAsync(cancellationToken).ConfigureAwait(false);
        var arguments = new List<string> { "exec", "--workdir", containerCwd };
        AppendContainerEnvironmentArguments(arguments, isolatedEnvironment);
        arguments.Add(container);
        arguments.Add(request.Executable);
        arguments.AddRange(request.Arguments);
        Touch();

        var result = await _docker.RunAsync(
            arguments,
            dockerEnvironment,
            request.TimeoutSeconds,
            request.OutputLimitBytes,
            cancellationToken).ConfigureAwait(false);
        ExecutionBackendContracts.ValidateProcessResult(result);
        if (result.ExitCode == 125 && !result.TimedOut && !result.Cancelled)
            SetHealth(new ExecutionBackendHealth(true, "degraded", "docker exec returned infrastructure error"));
        else
            SetHealth(new ExecutionBackendHealth(true, "ready"));
        return result;
    }

    public async Task<JsonObject> StartPtyAsync(
        string executable,
        IReadOnlyList<string> arguments,
        string cwd,
        IReadOnlyDictionary<string, string> environmentOverrides,
        int columns,
        int rows,
        int idleTtlSeconds,
        int maxLifetimeSeconds,
        bool spillOutput,
        CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        var containerCwd = ContainerWorkingDirectory(cwd);
        var isolatedEnvironment = BuildContainerEnvironment(environmentOverrides);
        _ = DockerClientEnvironment(environmentOverrides);
        var container = await EnsureContainerAsync(cancellationToken).ConfigureAwait(false);
        var dockerArguments = new List<string> { "exec", "-it", "--workdir", containerCwd };
        AppendContainerEnvironmentArguments(dockerArguments, isolatedEnvironment);
        dockerArguments.Add(container);
        dockerArguments.Add(executable);
        dockerArguments.AddRange(arguments);
        Touch();

        var result = await _pty.StartAsync(
            "docker",
            dockerArguments,
            "",
            environmentOverrides,
            columns,
            rows,
            idleTtlSeconds,
            maxLifetimeSeconds,
            spillOutput,
            cancellationToken).ConfigureAwait(false);
        SetHealth(new ExecutionBackendHealth(true, "ready"));
        return result;
    }

    public async Task<JsonObject> ReadPtyAsync(
        string sessionId,
        string cursor,
        int maxBytes,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        Touch();
        return await _pty.ReadAsync(sessionId, cursor, maxBytes, context, cancellationToken).ConfigureAwait(false);
    }

    public async Task<JsonObject> WritePtyAsync(string sessionId, string data, CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        Touch();
        return await _pty.WriteAsync(sessionId, data, cancellationToken).ConfigureAwait(false);
    }

    public JsonObject ResizePty(string sessionId, int columns, int rows)
    {
        ThrowIfDisposed();
        Touch();
        return _pty.Resize(sessionId, columns, rows);
    }

    public async Task<JsonObject> SignalPtyAsync(string sessionId, string signal, CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        Touch();
        return await _pty.SignalAsync(sessionId, signal, cancellationToken).ConfigureAwait(false);
    }

    public async Task<JsonObject> StopPtyAsync(string sessionId, CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        Touch();
        return await _pty.StopAsync(sessionId, cancellationToken).ConfigureAwait(false);
    }

    public JsonObject ListPty()
    {
        ThrowIfDisposed();
        Touch();
        return _pty.List();
    }

    public async Task StopAllAsync()
    {
        if (_disposed) return;
        try { await _pty.StopAllAsync().ConfigureAwait(false); } catch { }
        await RemoveCurrentContainerAsync(CancellationToken.None).ConfigureAwait(false);
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;
        _maintenanceCts.Cancel();
        try { await _maintenanceTask.ConfigureAwait(false); } catch (OperationCanceledException) { }
        try { await _pty.DisposeAsync().ConfigureAwait(false); } catch { }
        await RemoveCurrentContainerAsync(CancellationToken.None).ConfigureAwait(false);
        _maintenanceCts.Dispose();
        _containerGate.Dispose();
    }

    internal static void ValidateConfiguration(DockerExecutionBackendConfiguration configuration)
    {
        if (configuration.Image.Length is < 1 or > 512 || !DigestPinnedImagePattern.IsMatch(configuration.Image))
            throw new FileMcpException("Docker backend image must be an immutable digest-pinned reference");
        if (configuration.AllowedImages.Count is < 1 or > 16 ||
            configuration.AllowedImages.Any(image => image.Length > 512 || !DigestPinnedImagePattern.IsMatch(image)))
            throw new FileMcpException("Docker backend image allowlist must contain only bounded digest-pinned references");
        if (!configuration.AllowedImages.Contains(configuration.Image, StringComparer.Ordinal))
            throw new FileMcpException("Docker backend selected image is not in the local allowlist");
        if (configuration.CpuLimit is < 0.1 or > 32)
            throw new FileMcpException("Docker backend CPU limit must be 0.1..32");
        if (configuration.MemoryBytes is < (128L * 1024 * 1024) or > (64L * 1024 * 1024 * 1024))
            throw new FileMcpException("Docker backend memory limit must be 128 MiB..64 GiB");
        if (configuration.PidsLimit is < 16 or > 4096)
            throw new FileMcpException("Docker backend PID limit must be 16..4096");
        if (!UserPattern.IsMatch(configuration.User))
            throw new FileMcpException("Docker backend user must be an explicit bounded non-root user/group identity");
        if (configuration.User is "0" or "0:0" or "root" or "root:root")
            throw new FileMcpException("Docker backend refuses root container identity");
        if (configuration.StartupTimeoutSeconds is < 1 or > ProcessRunner.MaxCommandTimeoutSeconds)
            throw new FileMcpException($"Docker backend startup timeout must be 1..{ProcessRunner.MaxCommandTimeoutSeconds}");
        if (configuration.IdleTtlSeconds is < 60 or > 86_400)
            throw new FileMcpException("Docker backend idle TTL must be 60..86400 seconds");
        if (configuration.MaxLifetimeSeconds < configuration.IdleTtlSeconds || configuration.MaxLifetimeSeconds > 604_800)
            throw new FileMcpException("Docker backend max lifetime must be >= idle TTL and <= 604800 seconds");
    }

    internal IReadOnlyList<string> BuildCreateArgumentsForTest(string containerName, string leaseId) =>
        BuildCreateArguments(containerName, leaseId, RevalidatedWorkspaceRoot());

    internal IReadOnlyList<string> BuildExecArgumentsForTest(
        string containerId,
        ExecutionProcessRequest request,
        IReadOnlyDictionary<string, string> isolatedEnvironment)
    {
        var result = new List<string> { "exec", "--workdir", ContainerWorkingDirectory(request.Cwd) };
        AppendContainerEnvironmentArguments(result, isolatedEnvironment);
        result.Add(containerId);
        result.Add(request.Executable);
        result.AddRange(request.Arguments);
        return result;
    }

    internal IReadOnlyList<string> BuildPtyExecArgumentsForTest(
        string containerId,
        string executable,
        IReadOnlyList<string> arguments,
        string cwd,
        IReadOnlyDictionary<string, string> isolatedEnvironment)
    {
        var result = new List<string> { "exec", "-it", "--workdir", ContainerWorkingDirectory(cwd) };
        AppendContainerEnvironmentArguments(result, isolatedEnvironment);
        result.Add(containerId);
        result.Add(executable);
        result.AddRange(arguments);
        return result;
    }
    private IReadOnlyList<string> BuildCapabilities()
    {
        var capabilities = new List<string>
        {
            ExecutionBackendCapabilities.Process,
            ExecutionBackendCapabilities.Pty,
            ExecutionBackendCapabilities.WorkspaceMapping,
            ExecutionBackendCapabilities.EnvironmentMediation,
            ExecutionBackendCapabilities.Cleanup,
            ExecutionBackendCapabilities.Isolation,
            ExecutionBackendCapabilities.DigestPinnedImage,
            ExecutionBackendCapabilities.ResourceLimits,
            _configuration.NetworkEnabled ? ExecutionBackendCapabilities.NetworkEnabled : ExecutionBackendCapabilities.NetworkNone,
        };
        return capabilities;
    }

    private async Task<string> EnsureContainerAsync(CancellationToken cancellationToken)
    {
        await _containerGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            ThrowIfDisposed();
            if (ContainerExpired())
                await RemoveCurrentContainerLockedAsync(cancellationToken).ConfigureAwait(false);
            if (_containerId is not null)
            {
                Touch();
                return _containerId;
            }

            await ProbeDockerAsync(cancellationToken).ConfigureAwait(false);
            await ResolvePinnedImageAsync(cancellationToken).ConfigureAwait(false);
            await CleanupOwnedOrphansLockedAsync(cancellationToken).ConfigureAwait(false);

            var workspaceRoot = RevalidatedWorkspaceRoot();
            var leaseId = Convert.ToHexString(RandomNumberGenerator.GetBytes(12)).ToLowerInvariant();
            var workspaceSuffix = _workspaceAuthorityId["sha256:".Length..][..12];
            var containerName = $"filemcp-{workspaceSuffix}-{leaseId[..12]}";
            var create = await RunDockerCheckedAsync(
                BuildCreateArguments(containerName, leaseId, workspaceRoot),
                _configuration.StartupTimeoutSeconds,
                cancellationToken,
                "docker create").ConfigureAwait(false);
            var id = create.Stdout.Trim();
            if (!ContainerIdPattern.IsMatch(id))
                throw new FileMcpException("Docker backend create returned an invalid container identity");

            try
            {
                await RunDockerCheckedAsync(
                    ["start", id],
                    _configuration.StartupTimeoutSeconds,
                    cancellationToken,
                    "docker start").ConfigureAwait(false);
                await VerifyContainerSecurityAsync(id, workspaceRoot, leaseId, cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                await RemoveOwnedContainerBestEffortAsync(id, cancellationToken).ConfigureAwait(false);
                throw;
            }

            _containerId = id;
            _leaseId = leaseId;
            _containerCreatedUtc = DateTimeOffset.UtcNow;
            _lastActivityUtc = _containerCreatedUtc;
            SetHealth(new ExecutionBackendHealth(true, "ready"));
            return id;
        }
        finally
        {
            _containerGate.Release();
        }
    }

    private List<string> BuildCreateArguments(string containerName, string leaseId, string workspaceRoot)
    {
        var mount = $"type=bind,src={workspaceRoot},dst={WorkspaceDestination},rw";
        return
        [
            "create",
            "--pull", "never",
            "--no-healthcheck",
            "--name", containerName,
            "--label", $"{OwnerLabelKey}={OwnerLabelValue}",
            "--label", $"{BackendLabelKey}={BackendId}",
            "--label", $"{WorkspaceLabelKey}={_workspaceAuthorityId}",
            "--label", $"{LeaseLabelKey}={leaseId}",
            "--read-only",
            "--cap-drop", "ALL",
            "--security-opt", "no-new-privileges",
            "--pids-limit", _configuration.PidsLimit.ToString(CultureInfo.InvariantCulture),
            "--cpus", _configuration.CpuLimit.ToString("0.###", CultureInfo.InvariantCulture),
            "--memory", _configuration.MemoryBytes.ToString(CultureInfo.InvariantCulture),
            "--network", _configuration.NetworkEnabled ? "bridge" : "none",
            "--user", _configuration.User,
            "--tmpfs", "/tmp:rw,noexec,nosuid,nodev,size=67108864",
            "--mount", mount,
            _configuration.Image,
            "/bin/sh", "-c", "trap 'exit 0' TERM INT; while :; do sleep 3600; done",
        ];
    }

    private async Task ProbeDockerAsync(CancellationToken cancellationToken)
    {
        await RunDockerCheckedAsync(
            ["version", "--format", "{{.Server.Version}}"],
            Math.Min(_configuration.StartupTimeoutSeconds, 10),
            cancellationToken,
            "docker daemon probe").ConfigureAwait(false);
    }

    private async Task ResolvePinnedImageAsync(CancellationToken cancellationToken)
    {
        var result = await RunDockerCheckedAsync(
            ["image", "inspect", "--format", "{{json .RepoDigests}}", _configuration.Image],
            _configuration.StartupTimeoutSeconds,
            cancellationToken,
            "docker image inspect").ConfigureAwait(false);
        JsonNode? parsed;
        try { parsed = JsonNode.Parse(result.Stdout.Trim()); }
        catch (Exception ex) { throw new FileMcpException("Docker backend image digest inspection returned invalid JSON: " + ex.Message); }
        if (parsed is not JsonArray digests)
            throw new FileMcpException("Docker backend image digest inspection did not return a digest list");
        var resolved = digests
            .OfType<JsonValue>()
            .Select(node => node.TryGetValue<string>(out var value) ? value : null)
            .Where(value => value is not null)
            .Cast<string>()
            .ToList();
        if (!resolved.Contains(_configuration.Image, StringComparer.Ordinal) &&
            !resolved.Any(value => value.EndsWith("@" + _imageDigest, StringComparison.Ordinal)))
            throw new FileMcpException("Docker backend local image does not resolve to the configured immutable digest");
    }

    private async Task VerifyContainerSecurityAsync(
        string containerId,
        string workspaceRoot,
        string leaseId,
        CancellationToken cancellationToken)
    {
        var result = await RunDockerCheckedAsync(
            ["inspect", "--format", "{{json .}}", containerId],
            _configuration.StartupTimeoutSeconds,
            cancellationToken,
            "docker inspect").ConfigureAwait(false);
        JsonObject root;
        try { root = JsonNode.Parse(result.Stdout.Trim()) as JsonObject ?? throw new JsonException(); }
        catch (Exception ex) { throw new FileMcpException("Docker backend container inspection returned invalid JSON: " + ex.Message); }

        var hostConfig = root["HostConfig"] as JsonObject ?? throw new FileMcpException("Docker backend inspection is missing HostConfig");
        var config = root["Config"] as JsonObject ?? throw new FileMcpException("Docker backend inspection is missing Config");
        var labels = config["Labels"] as JsonObject ?? throw new FileMcpException("Docker backend inspection is missing ownership labels");
        RequireLabel(labels, OwnerLabelKey, OwnerLabelValue);
        RequireLabel(labels, BackendLabelKey, BackendId);
        RequireLabel(labels, WorkspaceLabelKey, _workspaceAuthorityId);
        RequireLabel(labels, LeaseLabelKey, leaseId);

        var expectedNetwork = _configuration.NetworkEnabled ? "bridge" : "none";
        if (!string.Equals(hostConfig["NetworkMode"]?.GetValue<string>(), expectedNetwork, StringComparison.Ordinal))
            throw new FileMcpException("Docker backend effective network policy does not match configured policy");
        if ((hostConfig["PidsLimit"]?.GetValue<long>() ?? 0) <= 0 ||
            (hostConfig["Memory"]?.GetValue<long>() ?? 0) <= 0 ||
            (hostConfig["NanoCpus"]?.GetValue<long>() ?? 0) <= 0)
            throw new FileMcpException("Docker backend effective resource caps are incomplete");

        var capDrop = hostConfig["CapDrop"] as JsonArray;
        if (capDrop is null || !capDrop.Any(node => string.Equals(node?.GetValue<string>(), "ALL", StringComparison.OrdinalIgnoreCase)))
            throw new FileMcpException("Docker backend effective capability drop is incomplete");
        var securityOpt = hostConfig["SecurityOpt"] as JsonArray;
        if (securityOpt is null || !securityOpt.Any(node => (node?.GetValue<string>() ?? "").Contains("no-new-privileges", StringComparison.OrdinalIgnoreCase)))
            throw new FileMcpException("Docker backend effective no-new-privileges policy is missing");
        if (!string.Equals(config["User"]?.GetValue<string>(), _configuration.User, StringComparison.Ordinal))
            throw new FileMcpException("Docker backend effective non-root user does not match local policy");

        var mounts = root["Mounts"] as JsonArray ?? throw new FileMcpException("Docker backend inspection is missing mounts");
        var bindMounts = mounts.OfType<JsonObject>()
            .Where(mount => string.Equals(mount["Type"]?.GetValue<string>(), "bind", StringComparison.OrdinalIgnoreCase))
            .ToList();
        if (bindMounts.Count != 1)
            throw new FileMcpException("Docker backend effective bind mounts are not limited to the workspace");
        var bind = bindMounts[0];
        var source = Path.GetFullPath(bind["Source"]?.GetValue<string>() ?? "");
        if (!_resolver.Contains(source) || !PathEquals(source, workspaceRoot) ||
            !string.Equals(bind["Destination"]?.GetValue<string>(), WorkspaceDestination, StringComparison.Ordinal) ||
            !(bind["RW"]?.GetValue<bool>() ?? false))
            throw new FileMcpException("Docker backend effective workspace mount is invalid");
    }

    private async Task CleanupOwnedOrphansLockedAsync(CancellationToken cancellationToken)
    {
        var listed = await RunDockerCheckedAsync(
            [
                "ps", "-a",
                "--filter", $"label={OwnerLabelKey}={OwnerLabelValue}",
                "--filter", $"label={BackendLabelKey}={BackendId}",
                "--filter", $"label={WorkspaceLabelKey}={_workspaceAuthorityId}",
                "--format", "{{.ID}}",
            ],
            _configuration.StartupTimeoutSeconds,
            cancellationToken,
            "docker orphan discovery").ConfigureAwait(false);
        foreach (var raw in listed.Stdout.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (!ContainerIdPattern.IsMatch(raw)) continue;
            if (await IsOwnedContainerAsync(raw, cancellationToken).ConfigureAwait(false))
                await RunDockerCheckedAsync(["rm", "-f", raw], _configuration.StartupTimeoutSeconds, cancellationToken, "docker orphan cleanup").ConfigureAwait(false);
        }
    }

    private async Task<bool> IsOwnedContainerAsync(string containerId, CancellationToken cancellationToken)
    {
        try
        {
            var result = await RunDockerCheckedAsync(
                ["inspect", "--format", "{{json .Config.Labels}}", containerId],
                _configuration.StartupTimeoutSeconds,
                cancellationToken,
                "docker ownership inspect").ConfigureAwait(false);
            var labels = JsonNode.Parse(result.Stdout.Trim()) as JsonObject;
            return labels is not null &&
                   LabelEquals(labels, OwnerLabelKey, OwnerLabelValue) &&
                   LabelEquals(labels, BackendLabelKey, BackendId) &&
                   LabelEquals(labels, WorkspaceLabelKey, _workspaceAuthorityId) &&
                   labels[LeaseLabelKey] is JsonValue lease && lease.TryGetValue<string>(out var value) &&
                   Regex.IsMatch(value, "^[0-9a-f]{24}$", RegexOptions.CultureInvariant);
        }
        catch { return false; }
    }

    private async Task RemoveCurrentContainerAsync(CancellationToken cancellationToken)
    {
        await _containerGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try { await RemoveCurrentContainerLockedAsync(cancellationToken).ConfigureAwait(false); }
        finally { _containerGate.Release(); }
    }

    private async Task RemoveCurrentContainerLockedAsync(CancellationToken cancellationToken)
    {
        var id = _containerId;
        _containerId = null;
        _leaseId = null;
        _containerCreatedUtc = null;
        _lastActivityUtc = null;
        if (id is null) return;
        await RemoveOwnedContainerBestEffortAsync(id, cancellationToken).ConfigureAwait(false);
    }

    private async Task RemoveOwnedContainerBestEffortAsync(string id, CancellationToken cancellationToken)
    {
        try
        {
            if (!await IsOwnedContainerAsync(id, cancellationToken).ConfigureAwait(false)) return;
            _ = await _docker.RunAsync(
                ["rm", "-f", id],
                DockerClientEnvironment(),
                _configuration.StartupTimeoutSeconds,
                DockerControlOutputLimit,
                cancellationToken).ConfigureAwait(false);
        }
        catch { }
    }

    private async Task MaintenanceLoopAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            await Task.Delay(TimeSpan.FromSeconds(30), cancellationToken).ConfigureAwait(false);
            if (_disposed) return;
            await _containerGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                if (ContainerExpired())
                {
                    try { await _pty.StopAllAsync().ConfigureAwait(false); } catch { }
                    await RemoveCurrentContainerLockedAsync(cancellationToken).ConfigureAwait(false);
                }
            }
            finally { _containerGate.Release(); }
        }
    }

    private bool ContainerExpired()
    {
        if (_containerId is null || _containerCreatedUtc is null || _lastActivityUtc is null) return false;
        var now = DateTimeOffset.UtcNow;
        return now - _lastActivityUtc.Value >= TimeSpan.FromSeconds(_configuration.IdleTtlSeconds) ||
               now - _containerCreatedUtc.Value >= TimeSpan.FromSeconds(_configuration.MaxLifetimeSeconds);
    }

    private string RevalidatedWorkspaceRoot()
    {
        var root = _resolver.Resolve("");
        if (!_resolver.Contains(root) || root.IndexOfAny([',', '\r', '\n', '\0']) >= 0)
            throw new FileMcpException("Docker backend workspace mount source is not safely representable");
        return root;
    }

    private string ContainerWorkingDirectory(string cwd)
    {
        var resolved = _resolver.Resolve(cwd);
        var relative = _resolver.RelativePath(resolved);
        if (string.IsNullOrEmpty(relative)) return WorkspaceDestination;
        var safe = relative.Replace('\\', '/').TrimStart('/');
        return WorkspaceDestination + "/" + safe;
    }

    private Dictionary<string, string> BuildContainerEnvironment(IReadOnlyDictionary<string, string>? overrides)
    {
        if (overrides is not null)
        {
            var reserved = overrides.Keys.FirstOrDefault(name =>
                DockerControlEnvironmentNames.Contains(name, StringComparer.OrdinalIgnoreCase));
            if (reserved is not null)
                throw new FileMcpException($"Environment override is reserved by the Docker execution backend: {reserved}");
        }

        var environment = _environmentAuthority.BuildIsolated(overrides);
        foreach (var name in DockerControlEnvironmentNames)
            environment.Remove(name);
        return environment;
    }

    private Dictionary<string, string> DockerClientEnvironment(IReadOnlyDictionary<string, string>? overrides = null) =>
        _dockerClientEnvironmentAuthority.Build(overrides);

    private async Task<ProcessResult> RunDockerCheckedAsync(
        IReadOnlyList<string> arguments,
        int timeoutSeconds,
        CancellationToken cancellationToken,
        string operation)
    {
        ProcessResult result;
        try
        {
            result = await _docker.RunAsync(
                arguments,
                DockerClientEnvironment(),
                timeoutSeconds,
                DockerControlOutputLimit,
                cancellationToken).ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            SetHealth(new ExecutionBackendHealth(true, "degraded", operation + " unavailable"));
            throw new FileMcpException($"{operation} unavailable: {ex.Message}");
        }

        if (result.Cancelled) throw new OperationCanceledException(cancellationToken);
        if (result.TimedOut)
        {
            SetHealth(new ExecutionBackendHealth(true, "degraded", operation + " timed out"));
            throw new FileMcpException($"{operation} timed out");
        }
        if (result.ExitCode != 0)
        {
            SetHealth(new ExecutionBackendHealth(true, "degraded", operation + " failed"));
            var detail = string.IsNullOrWhiteSpace(result.Stderr) ? result.Stdout : result.Stderr;
            detail = detail.Trim();
            if (detail.Length > 1000) detail = detail[..1000];
            throw new FileMcpException($"{operation} failed: {detail}");
        }
        return result;
    }

    private static void AppendContainerEnvironmentArguments(List<string> arguments, IReadOnlyDictionary<string, string> environment)
    {
        foreach (var name in environment.Keys.Order(StringComparer.Ordinal))
        {
            arguments.Add("--env");
            arguments.Add(name);
        }
    }

    private static void RequireLabel(JsonObject labels, string key, string expected)
    {
        if (!LabelEquals(labels, key, expected))
            throw new FileMcpException($"Docker backend ownership label mismatch: {key}");
    }

    private static bool LabelEquals(JsonObject labels, string key, string expected) =>
        labels[key] is JsonValue value &&
        value.TryGetValue<string>(out var actual) &&
        string.Equals(actual, expected, StringComparison.Ordinal);

    private static bool PathEquals(string left, string right) =>
        string.Equals(
            Path.GetFullPath(left).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
            Path.GetFullPath(right).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
            OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal);

    private void Touch() => _lastActivityUtc = DateTimeOffset.UtcNow;

    private void SetHealth(ExecutionBackendHealth health)
    {
        lock (_healthGate)
        {
            if (!_disposed) _health = health;
        }
    }

    private void ThrowIfDisposed()
    {
        if (_disposed) throw new FileMcpException("Execution backend is disposed");
    }
}
