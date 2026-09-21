using System.Diagnostics;

namespace FileMCP.Core;

public sealed record WorkspaceObservabilitySnapshot(
    string WorkspaceKey,
    UsageCounters LifetimeUsage,
    bool RuntimeRunning,
    TimeSpan RuntimeUptime);

public sealed record ObservabilitySnapshot(
    TimeSpan AppUptime,
    UsageCounters GlobalUsage,
    IReadOnlyDictionary<string, WorkspaceObservabilitySnapshot> Workspaces);

public sealed class ObservabilityHub : IAsyncDisposable
{
    private readonly Dictionary<string, WorkspaceUsageMeter> _meters;
    private readonly Dictionary<string, long> _runtimeStartedTicks;
    private readonly object _runtimeGate = new();
    private readonly long _appStartedTicks = Stopwatch.GetTimestamp();
    private readonly TelemetrySqliteStore _store;
    private readonly TelemetryWriter _writer;
    private readonly SemaphoreSlim _startGate = new(1, 1);
    private bool _started;
    private bool _disposed;

    public ObservabilityHub(
        IEnumerable<string> workspaceKeys,
        string? databasePath = null,
        TimeSpan? writerInterval = null,
        Action<string>? log = null)
    {
        var keys = workspaceKeys
            .Where(key => !string.IsNullOrWhiteSpace(key))
            .Select(key => key.Trim().ToUpperInvariant())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        if (keys.Length == 0) throw new ArgumentException("At least one workspace key is required.", nameof(workspaceKeys));

        _meters = keys.ToDictionary(key => key, key => new WorkspaceUsageMeter(key), StringComparer.OrdinalIgnoreCase);
        _runtimeStartedTicks = keys.ToDictionary(key => key, _ => 0L, StringComparer.OrdinalIgnoreCase);
        _store = new TelemetrySqliteStore(databasePath);
        _writer = new TelemetryWriter(_meters.Values, _store, writerInterval, log);
    }

    public WorkspaceUsageMeter MeterFor(string workspaceKey)
    {
        var key = NormalizeWorkspaceKey(workspaceKey);
        return _meters.TryGetValue(key, out var meter)
            ? meter
            : throw new KeyNotFoundException($"Unknown FileMCP workspace key '{workspaceKey}'.");
    }

    public async Task StartAsync(CancellationToken cancellationToken = default)
    {
        ThrowIfDisposed();
        if (_started) return;
        await _startGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_started) return;
            await _writer.StartAsync(cancellationToken).ConfigureAwait(false);
            _started = true;
        }
        finally
        {
            _startGate.Release();
        }
    }

    public void MarkRuntimeRunning(string workspaceKey)
    {
        var key = NormalizeWorkspaceKey(workspaceKey);
        lock (_runtimeGate)
        {
            if (!_runtimeStartedTicks.ContainsKey(key)) throw new KeyNotFoundException($"Unknown FileMCP workspace key '{workspaceKey}'.");
            if (_runtimeStartedTicks[key] == 0) _runtimeStartedTicks[key] = Stopwatch.GetTimestamp();
        }
    }

    public void MarkRuntimeStopped(string workspaceKey)
    {
        var key = NormalizeWorkspaceKey(workspaceKey);
        lock (_runtimeGate)
        {
            if (!_runtimeStartedTicks.ContainsKey(key)) throw new KeyNotFoundException($"Unknown FileMCP workspace key '{workspaceKey}'.");
            _runtimeStartedTicks[key] = 0;
        }
    }

    public ObservabilitySnapshot Snapshot()
    {
        ThrowIfDisposed();
        Dictionary<string, long> starts;
        lock (_runtimeGate) starts = new Dictionary<string, long>(_runtimeStartedTicks, StringComparer.OrdinalIgnoreCase);

        var workspaces = new Dictionary<string, WorkspaceObservabilitySnapshot>(StringComparer.OrdinalIgnoreCase);
        var global = default(UsageCounters);
        foreach (var pair in _meters)
        {
            var usage = pair.Value.Snapshot();
            global += usage;
            var started = starts[pair.Key];
            workspaces[pair.Key] = new WorkspaceObservabilitySnapshot(
                pair.Key,
                usage,
                started != 0,
                started == 0 ? TimeSpan.Zero : Stopwatch.GetElapsedTime(started));
        }
        return new ObservabilitySnapshot(Stopwatch.GetElapsedTime(_appStartedTicks), global, workspaces);
    }

    public Task<UsageCounters> QueryExactPeriodAsync(UsagePeriodRange range, string? workspaceKey = null, CancellationToken cancellationToken = default)
    {
        ThrowIfDisposed();
        var key = workspaceKey is null ? null : NormalizeWorkspaceKey(workspaceKey);
        if (key is not null && !_meters.ContainsKey(key)) throw new KeyNotFoundException($"Unknown FileMCP workspace key '{workspaceKey}'.");
        return _store.QueryExactPeriodAsync(range, key, cancellationToken);
    }

    public Task CleanupRetentionAsync(DateTimeOffset nowUtc, CancellationToken cancellationToken = default)
    {
        ThrowIfDisposed();
        return _store.CleanupRetentionAsync(nowUtc, cancellationToken);
    }

    internal Task FlushOnceForTestsAsync(DateTimeOffset capturedAtUtc, CancellationToken cancellationToken = default) =>
        _writer.FlushOnceAsync(capturedAtUtc, cancellationToken);

    private static string NormalizeWorkspaceKey(string workspaceKey)
    {
        if (string.IsNullOrWhiteSpace(workspaceKey)) throw new ArgumentException("Workspace key cannot be empty.", nameof(workspaceKey));
        return workspaceKey.Trim().ToUpperInvariant();
    }

    private void ThrowIfDisposed()
    {
        if (_disposed) throw new ObjectDisposedException(nameof(ObservabilityHub));
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;
        await _writer.DisposeAsync().ConfigureAwait(false);
        _startGate.Dispose();
    }
}