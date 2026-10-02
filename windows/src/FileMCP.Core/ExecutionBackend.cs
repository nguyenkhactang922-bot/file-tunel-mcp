using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace FileMCP.Core;

internal static class ExecutionBackendCapabilities
{
    public const string Process = "process";
    public const string Pty = "pty";
    public const string WorkspaceMapping = "workspace_mapping";
    public const string EnvironmentMediation = "environment_mediation";
    public const string HostNetwork = "host_network";
    public const string Cleanup = "cleanup";
}

internal sealed record ExecutionBackendDescriptor(
    string Id,
    string Version,
    IReadOnlyList<string> Capabilities,
    string WorkspaceMode,
    string EnvironmentMode,
    string NetworkMode,
    string ResourceMode);

internal sealed record ExecutionBackendHealth(bool Available, string State, string? Detail = null);

internal sealed record ExecutionProcessRequest(
    string Executable,
    IReadOnlyList<string> Arguments,
    string Cwd,
    IReadOnlyDictionary<string, string> EnvironmentOverrides,
    int TimeoutSeconds,
    int OutputLimitBytes);

internal interface IExecutionBackend : IAsyncDisposable
{
    ExecutionBackendDescriptor Descriptor { get; }
    ExecutionBackendHealth Health { get; }

    Task<ProcessResult> RunProcessAsync(ExecutionProcessRequest request, CancellationToken cancellationToken);

    Task<JsonObject> StartPtyAsync(
        string executable,
        IReadOnlyList<string> arguments,
        string cwd,
        IReadOnlyDictionary<string, string> environmentOverrides,
        int columns,
        int rows,
        int idleTtlSeconds,
        int maxLifetimeSeconds,
        bool spillOutput,
        CancellationToken cancellationToken);

    Task<JsonObject> ReadPtyAsync(
        string sessionId,
        string cursor,
        int maxBytes,
        ToolExecutionContext? context,
        CancellationToken cancellationToken);

    Task<JsonObject> WritePtyAsync(string sessionId, string data, CancellationToken cancellationToken);
    JsonObject ResizePty(string sessionId, int columns, int rows);
    Task<JsonObject> SignalPtyAsync(string sessionId, string signal, CancellationToken cancellationToken);
    Task<JsonObject> StopPtyAsync(string sessionId, CancellationToken cancellationToken);
    JsonObject ListPty();
    Task StopAllAsync();
}

internal static class ExecutionBackendContracts
{
    private static readonly Regex IdentifierPattern = new(
        "^[a-z0-9][a-z0-9._-]{0,63}$",
        RegexOptions.CultureInvariant | RegexOptions.Compiled);

    public static void ValidateDescriptor(ExecutionBackendDescriptor descriptor)
    {
        if (!IdentifierPattern.IsMatch(descriptor.Id))
            throw new FileMcpException("Execution backend identity is invalid");
        if (string.IsNullOrWhiteSpace(descriptor.Version) || descriptor.Version.Length > 64 ||
            descriptor.Version.Any(char.IsWhiteSpace))
            throw new FileMcpException("Execution backend version is invalid");
        if (descriptor.Capabilities.Count is < 1 or > 32)
            throw new FileMcpException("Execution backend capabilities are invalid");

        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var capability in descriptor.Capabilities)
        {
            if (!IdentifierPattern.IsMatch(capability) || !seen.Add(capability))
                throw new FileMcpException("Execution backend capability set is invalid");
        }

        foreach (var mode in new[]
        {
            descriptor.WorkspaceMode,
            descriptor.EnvironmentMode,
            descriptor.NetworkMode,
            descriptor.ResourceMode,
        })
        {
            if (!IdentifierPattern.IsMatch(mode))
                throw new FileMcpException("Execution backend descriptor modes are invalid");
        }
    }

    public static void ValidateHealth(ExecutionBackendHealth health)
    {
        if (health.State is not ("ready" or "unavailable" or "degraded" or "disposed"))
            throw new FileMcpException("Execution backend health state is invalid");
        if (health.Available && health.State is "unavailable" or "disposed")
            throw new FileMcpException("Execution backend health is inconsistent");
    }

    public static void RequireCapability(ExecutionBackendDescriptor descriptor, string capability)
    {
        ValidateDescriptor(descriptor);
        if (!descriptor.Capabilities.Contains(capability, StringComparer.Ordinal))
            throw new FileMcpException($"Execution backend does not support required capability: {capability}");
    }

    public static void ValidateProcessResult(ProcessResult result)
    {
        if (result.TimedOut && result.Cancelled)
            throw new FileMcpException("Execution backend returned an invalid process terminal state");
        if (result.StdoutOmittedBytes < 0 || result.StderrOmittedBytes < 0)
            throw new FileMcpException("Execution backend returned invalid omitted-byte counters");
        if (result.StdoutTruncated != (result.StdoutOmittedBytes > 0) ||
            result.StderrTruncated != (result.StderrOmittedBytes > 0))
            throw new FileMcpException("Execution backend returned inconsistent truncation metadata");
    }

    public static JsonObject AttachMetadata(JsonObject result, ExecutionBackendDescriptor descriptor)
    {
        ValidateDescriptor(descriptor);
        result["backend_id"] = descriptor.Id;
        result["backend_version"] = descriptor.Version;
        var capabilities = new JsonArray();
        foreach (var capability in descriptor.Capabilities.Order(StringComparer.Ordinal))
            capabilities.Add(JsonValue.Create(capability));
        result["backend_capabilities"] = capabilities;
        result["backend_workspace_mode"] = descriptor.WorkspaceMode;
        result["backend_environment_mode"] = descriptor.EnvironmentMode;
        result["backend_network_mode"] = descriptor.NetworkMode;
        result["backend_resource_mode"] = descriptor.ResourceMode;
        return result;
    }
}

internal sealed class HostExecutionBackend : IExecutionBackend
{
    public const string BackendId = "host-native";
    public const string BackendVersion = "1.0.0";

    private static readonly ExecutionBackendDescriptor HostDescriptor = new(
        BackendId,
        BackendVersion,
        [
            ExecutionBackendCapabilities.Process,
            ExecutionBackendCapabilities.Pty,
            ExecutionBackendCapabilities.WorkspaceMapping,
            ExecutionBackendCapabilities.EnvironmentMediation,
            ExecutionBackendCapabilities.HostNetwork,
            ExecutionBackendCapabilities.Cleanup,
        ],
        WorkspaceMode: "host-contained",
        EnvironmentMode: "mediated",
        NetworkMode: "host",
        ResourceMode: "host-process");

    private readonly SafePathResolver _resolver;
    private readonly ExecProcessEnvironmentAuthority _environmentAuthority;
    private readonly PersistentPtyService _pty;
    private bool _disposed;

    public HostExecutionBackend(
        SafePathResolver resolver,
        ExecProcessEnvironmentAuthority environmentAuthority,
        Func<ArtifactContentStore> artifactFactory)
    {
        ExecutionBackendContracts.ValidateDescriptor(HostDescriptor);
        _resolver = resolver;
        _environmentAuthority = environmentAuthority;
        _pty = new PersistentPtyService(resolver, environmentAuthority, artifactFactory);
    }

    public ExecutionBackendDescriptor Descriptor => HostDescriptor;
    public ExecutionBackendHealth Health => _disposed
        ? new ExecutionBackendHealth(false, "disposed")
        : new ExecutionBackendHealth(true, "ready");

    public async Task<ProcessResult> RunProcessAsync(ExecutionProcessRequest request, CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        var workdir = _resolver.Resolve(request.Cwd);
        if (!Directory.Exists(workdir))
            throw new FileMcpException($"No such working directory: {(string.IsNullOrEmpty(request.Cwd) ? "." : request.Cwd)}");
        var environment = _environmentAuthority.Build(request.EnvironmentOverrides);
        var result = await ProcessRunner.RunAsync(
            request.Executable,
            request.Arguments,
            workdir,
            environment,
            request.TimeoutSeconds,
            request.OutputLimitBytes,
            cancellationToken).ConfigureAwait(false);
        ExecutionBackendContracts.ValidateProcessResult(result);
        return result;
    }

    public Task<JsonObject> StartPtyAsync(
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
        return _pty.StartAsync(
            executable, arguments, cwd, environmentOverrides, columns, rows,
            idleTtlSeconds, maxLifetimeSeconds, spillOutput, cancellationToken);
    }

    public Task<JsonObject> ReadPtyAsync(
        string sessionId,
        string cursor,
        int maxBytes,
        ToolExecutionContext? context,
        CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        return _pty.ReadAsync(sessionId, cursor, maxBytes, context, cancellationToken);
    }

    public Task<JsonObject> WritePtyAsync(string sessionId, string data, CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        return _pty.WriteAsync(sessionId, data, cancellationToken);
    }

    public JsonObject ResizePty(string sessionId, int columns, int rows)
    {
        ThrowIfDisposed();
        return _pty.Resize(sessionId, columns, rows);
    }

    public Task<JsonObject> SignalPtyAsync(string sessionId, string signal, CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        return _pty.SignalAsync(sessionId, signal, cancellationToken);
    }

    public Task<JsonObject> StopPtyAsync(string sessionId, CancellationToken cancellationToken)
    {
        ThrowIfDisposed();
        return _pty.StopAsync(sessionId, cancellationToken);
    }

    public JsonObject ListPty()
    {
        ThrowIfDisposed();
        return _pty.List();
    }

    public Task StopAllAsync()
    {
        if (_disposed) return Task.CompletedTask;
        return _pty.StopAllAsync();
    }

    private void ThrowIfDisposed()
    {
        if (_disposed) throw new FileMcpException("Execution backend is disposed");
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;
        await _pty.DisposeAsync().ConfigureAwait(false);
    }
}
