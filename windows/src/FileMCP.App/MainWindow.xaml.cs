using System.Diagnostics;
using System.ComponentModel;
using System.Drawing;
using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using FileMCP.Core;
using FileMCP.App.Presentation;
using Microsoft.Win32;
using Forms = System.Windows.Forms;

namespace FileMCP.App;

public partial class MainWindow : Window
{
    private static readonly string[] WorkspaceKeys = ["C", "D", "E", "F"];

    private readonly SettingsStore _settingsStore = new();
    private readonly WindowsCredentialStore _credentialStore = new();
    private readonly Dictionary<string, LocalMcpRuntime> _runtimes = new(StringComparer.OrdinalIgnoreCase);
    private readonly ObservabilityHub _observability;
    private readonly DispatcherTimer _overviewTimer;
    private readonly Forms.NotifyIcon _trayIcon;
    private FileMcpSettings _settings;
    private bool _quitting;
    private bool _navigationCompact;
    private UsagePeriodPreset _selectedOverviewPeriod = UsagePeriodPreset.Today;
    private DateTimeOffset _lastOverviewPeriodRefreshUtc = DateTimeOffset.MinValue;
    private int _overviewPeriodQueryGeneration;
    private bool _overviewPeriodQueryRunning;
    private string _logBuffer = "";
    private readonly List<ActivityRow> _activityRows = new();
    private readonly List<ChangeRow> _changeRows = new();
    private readonly List<EvidenceRow> _evidenceRows = new();
    private readonly List<RepositoryResultRow> _repositoryRows = new();
    private readonly List<TerminalSessionRow> _terminalRows = new();
    private readonly Dictionary<string, string> _terminalReadCursors = new(StringComparer.Ordinal);
    private readonly List<RecoveryQuarantineRow> _recoveryQuarantineRows = new();
    private readonly List<RecoveryCheckpointRow> _recoveryCheckpointRows = new();
    private readonly HashSet<string> _plannedCheckpointKeys = new(StringComparer.Ordinal);
    private readonly List<ArtifactBatchRow> _artifactBatchRows = new();
    private readonly List<BackendStatusRow> _backendRows = new();
    private bool _terminalRefreshRunning;
    private bool _recoveryRefreshRunning;
    private bool _livePresentationRefreshScheduled;
    private string _recoveryPersistentNotice = "";
    private const int TerminalReadWindowBytes = 16 * 1024;
    private const int MaxTerminalOutputCharacters = 64 * 1024;
    private const int MaxActivityRows = 500;
    private const int MaxChangeRows = 250;
    private const int MaxEvidenceRows = 500;
    private const int MaxRepositoryRows = 100;
    private const int MaxArtifactBatchRows = 100;
    private string _lastImportantEvent = "No recent issue";
    private const int MaxLogCharacters = 500_000;

    public MainWindow()
    {
        InitializeComponent();
        var observabilityDatabaseOverride = Environment.GetEnvironmentVariable("FILEMCP_OBSERVABILITY_DB");
        _observability = new ObservabilityHub(
            WorkspaceKeys,
            string.IsNullOrWhiteSpace(observabilityDatabaseOverride) ? null : observabilityDatabaseOverride,
            log: text => Dispatcher.BeginInvoke(new Action(() => AppendLog(text))));
        _overviewTimer = new DispatcherTimer(DispatcherPriority.Background, Dispatcher) { Interval = TimeSpan.FromSeconds(1) };
        _overviewTimer.Tick += OverviewTimer_Tick;
        OverviewPeriodCombo.SelectionChanged += OverviewPeriodCombo_SelectionChanged;
        _settings = LoadSettingsSafely();
        ApplySettings(_settings);
        ConfigureOtlpFromSettings();
        UpdateApiKeyStatus();

        foreach (var key in WorkspaceKeys)
        {
            var capturedKey = key;
            var runtime = new LocalMcpRuntime(capturedKey, _observability);
            runtime.Log += text => Dispatcher.BeginInvoke(new Action(() => AppendLog($"[{capturedKey}] {text}")));
            runtime.StateChanged += state => Dispatcher.BeginInvoke(new Action(() => UpdateRuntimeState(capturedKey, state)));
            _runtimes[capturedKey] = runtime;
        }

        Closing += OnClosing;
        PreviewKeyDown += OnPreviewKeyDown;

        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Open FileMCP", null, (_, _) => Dispatcher.Invoke(ShowFromTray));
        menu.Items.Add("About FileMCP", null, (_, _) => Dispatcher.Invoke(ShowAbout));
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Quit FileMCP", null, (_, _) => Dispatcher.Invoke(async () => await QuitAsync()));
        _trayIcon = new Forms.NotifyIcon
        {
            Text = "FileMCP",
            Visible = true,
            ContextMenuStrip = menu,
            Icon = LoadApplicationIcon(),
        };
        _trayIcon.DoubleClick += (_, _) => Dispatcher.Invoke(ShowFromTray);

        RefreshRuntimeUi();
        InitializeOnboardingExperience();
        _ = StartObservabilityAsync();
        RefreshOverviewLiveUi();
        _ = RefreshOverviewPeriodAsync(force: true);
        _overviewTimer.Start();
    }

    private async Task StartObservabilityAsync()
    {
        try
        {
            await _observability.StartAsync();
            await RunObservabilityPackageSmokeIfRequestedAsync();
            await RunOtlpPackageSmokeIfRequestedAsync();
            AppendLog("[Telemetry] Observability store ready.\n");
        }
        catch (Exception ex)
        {
            AppendLog($"[Telemetry] Persistent observability unavailable; MCP remains operational: {ex.Message}\n");
        }
    }
    private async Task RunObservabilityPackageSmokeIfRequestedAsync()
    {
        var markerPath = Environment.GetEnvironmentVariable("FILEMCP_OBSERVABILITY_SMOKE_MARKER");
        if (string.IsNullOrWhiteSpace(markerPath)) return;

        try
        {
            var now = DateTimeOffset.UtcNow;
            var meter = _observability.MeterFor("C");
            meter.RecordRequest(4);
            meter.RecordResponse(4);
            meter.RecordToolCall("read_file", isError: false, latencyTicks: 1);
            await _observability.FlushAsync(now);

            var unix = now.ToUnixTimeSeconds();
            var minuteStart = DateTimeOffset.FromUnixTimeSeconds(unix - unix % 60);
            var persisted = await _observability.QueryExactPeriodAsync(
                new UsagePeriodRange(minuteStart, now.AddMinutes(1)),
                "C");
            if (persisted.ToolCalls < 1 || persisted.ReadCalls < 1 || persisted.RequestBytes < 4 || persisted.ResponseBytes < 4)
                throw new InvalidOperationException("Packaged SQLite telemetry write/read verification returned incomplete counters.");

            var directory = Path.GetDirectoryName(Path.GetFullPath(markerPath));
            if (!string.IsNullOrWhiteSpace(directory)) Directory.CreateDirectory(directory);
            await File.WriteAllTextAsync(
                markerPath,
                $"PASS tool_calls={persisted.ToolCalls} read_calls={persisted.ReadCalls}");
        }
        catch (Exception ex)
        {
            try { await File.WriteAllTextAsync(markerPath, "FAIL " + ex.Message); } catch { }
            throw;
        }
    }
    private async Task RunOtlpPackageSmokeIfRequestedAsync()
    {
        var markerPath = Environment.GetEnvironmentVariable("FILEMCP_OTLP_SMOKE_MARKER");
        if (string.IsNullOrWhiteSpace(markerPath)) return;

        var endpoint = Environment.GetEnvironmentVariable("FILEMCP_OTLP_SMOKE_ENDPOINT");
        if (string.IsNullOrWhiteSpace(endpoint)) endpoint = "http://127.0.0.1:1";
        try
        {
            var configured = _observability.ConfigureOtlp(new OtlpTelemetrySettings(true, endpoint));
            if (configured.Status != OtlpExporterRuntimeStatus.Configured)
                throw new InvalidOperationException("Packaged OTLP provider configuration failed: " + configured.Error);

            using (var operation = _observability.StandardTelemetry.BeginOperation(
                       FileMcpConstants.ModernProtocolVersion,
                       "tools/call",
                       "read_file",
                       "C",
                       4))
                operation.Complete(4, isError: false);

            await Task.Delay(100);
            var directory = Path.GetDirectoryName(Path.GetFullPath(markerPath));
            if (!string.IsNullOrWhiteSpace(directory)) Directory.CreateDirectory(directory);
            await File.WriteAllTextAsync(markerPath, $"PASS status={configured.Status} endpoint={configured.Endpoint}");
        }
        catch (Exception ex)
        {
            try { await File.WriteAllTextAsync(markerPath, "FAIL " + ex.Message); } catch { }
            throw;
        }
        finally
        {
            ConfigureOtlpFromSettings();
        }
    }
    private async void OverviewTimer_Tick(object? sender, EventArgs e)
    {
        await RefreshRuntimeHealthAsync();
        RefreshOverviewLiveUi();
        if (MainTabs.SelectedItem == TerminalTab)
            await RefreshTerminalAsync(readSelectedOutput: true);
        if (DateTimeOffset.UtcNow - _lastOverviewPeriodRefreshUtc >= TimeSpan.FromSeconds(5))
            await RefreshOverviewPeriodAsync(force: false);
    }

    private async Task RefreshRuntimeHealthAsync()
    {
        if (_quitting) return;
        try
        {
            await Task.WhenAll(_runtimes.Values.Select(runtime => runtime.RefreshHealthAsync()));
        }
        catch (ObjectDisposedException) when (_quitting) { }
    }

    private void OverviewPeriodCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _selectedOverviewPeriod = OverviewPeriodCombo.SelectedIndex switch
        {
            1 => UsagePeriodPreset.Yesterday,
            2 => UsagePeriodPreset.SevenDays,
            3 => UsagePeriodPreset.ThirtyDays,
            _ => UsagePeriodPreset.Today,
        };
        _ = RefreshOverviewPeriodAsync(force: true);
    }

    private void RefreshOverviewLiveUi()
    {
        if (_quitting) return;
        ObservabilitySnapshot snapshot;
        try { snapshot = _observability.Snapshot(); }
        catch (ObjectDisposedException) { return; }

        OverviewClockText.Text = DateTimeOffset.Now.ToString("ddd, dd/MM/yyyy  HH:mm:ss");
        OverviewAppUptimeText.Text = "App uptime: " + FormatDuration(snapshot.AppUptime);
        foreach (var key in WorkspaceKeys)
            if (snapshot.Workspaces.TryGetValue(key, out var workspace)) UpdateOverviewWorkspaceLive(key, workspace, _runtimes[key].HealthSnapshot);

        var realtime = _observability.CaptureRealtimeSample();
        UpdateOverviewHealth(snapshot);
        UpdateHomeSummary(snapshot);
        UpdateRealtimeGraph(realtime);
        RefreshObservedSessionsUi();
    }

    private void UpdateHomeSummary(ObservabilitySnapshot snapshot)
    {
        var active = WorkspaceKeys.Where(key => EnabledBox(key).IsChecked == true).ToArray();
        var running = snapshot.Workspaces.Values.Count(workspace => workspace.RuntimeRunning);
        var failed = _runtimes.Values.Count(runtime => runtime.State.Status == LocalMcpRuntimeStatus.Failed);

        HomeHeader.Status = failed > 0
            ? PresentationStatus.Failed
            : running > 0 && running == active.Length
                ? PresentationStatus.Healthy
                : running > 0
                    ? PresentationStatus.Degraded
                    : PresentationStatus.Stopped;

        HomeSummaryText.Text = running == 0
            ? "No runtime is currently connected."
            : $"{running} runtime(s) connected; {snapshot.GlobalUsage.ToolCalls:N0} tool call(s) observed.";
        HomeActiveWorkspacesText.Text = active.Length == 0 ? "None" : string.Join(", ", active);
        HomeRunningWorkText.Text = $"{running} runtime(s)";
        HomeRecentEventText.Text = _lastImportantEvent;
    }

    private void UpdateOverviewHealth(ObservabilitySnapshot snapshot)
    {
        var connected = snapshot.Workspaces.Values.Count(workspace => workspace.RuntimeRunning);
        var usage = snapshot.GlobalUsage;
        var averageMs = usage.ToolCalls == 0
            ? 0d
            : (double)usage.TotalLatencyTicks / Stopwatch.Frequency / usage.ToolCalls * 1_000d;
        var maxMs = usage.MaxLatencyTicks <= 0
            ? 0d
            : (double)usage.MaxLatencyTicks / Stopwatch.Frequency * 1_000d;

        OverviewConnectedRuntimesText.Text = $"{connected} / {WorkspaceKeys.Length}";
        OverviewAverageLatencyText.Text = $"{averageMs:N1} ms";
        OverviewMaxLatencyText.Text = $"{maxMs:N1} ms";
        var persistenceText = snapshot.Persistence.Status switch
        {
            TelemetryPersistenceStatus.Ready => "Ready",
            TelemetryPersistenceStatus.Degraded => $"Degraded ({snapshot.Persistence.FailureCount:N0})",
            _ => "Starting",
        };
        var otlpText = snapshot.Otlp.Status switch
        {
            OtlpExporterRuntimeStatus.Configured => "OTLP on",
            OtlpExporterRuntimeStatus.ConfigurationError => "OTLP error",
            _ => "OTLP off",
        };
        OverviewTelemetryHealthText.Text = $"{persistenceText} | {otlpText}";
        OverviewTelemetryHealthText.Foreground = snapshot.Persistence.Status switch
        {
            TelemetryPersistenceStatus.Ready => System.Windows.Media.Brushes.ForestGreen,
            TelemetryPersistenceStatus.Degraded => System.Windows.Media.Brushes.DarkOrange,
            _ => System.Windows.Media.Brushes.Gray,
        };
    }

    private void UpdateRealtimeGraph(RealtimeUsageSample current)
    {
        OverviewRealtimeCurrentText.Text = $"Calls/s: {FormatCount(current.Delta.ToolCalls)} | Tokens est./s: {FormatCount(current.Delta.TotalTokensEst)}";
        var samples = _observability.RealtimeSamples();
        var width = OverviewRealtimeCanvas.ActualWidth;
        var height = OverviewRealtimeCanvas.ActualHeight;
        if (samples.Count < 2 || width <= 1 || height <= 1)
        {
            OverviewCallsPolyline.Points = new PointCollection();
            OverviewTokensPolyline.Points = new PointCollection();
            return;
        }

        OverviewCallsPolyline.Points = BuildRealtimePoints(samples, sample => sample.Delta.ToolCalls, width, height);
        OverviewTokensPolyline.Points = BuildRealtimePoints(samples, sample => sample.Delta.TotalTokensEst, width, height);
    }

    private static PointCollection BuildRealtimePoints(
        IReadOnlyList<RealtimeUsageSample> samples,
        Func<RealtimeUsageSample, long> selector,
        double width,
        double height)
    {
        var max = Math.Max(1L, samples.Max(selector));
        var denominator = Math.Max(1, samples.Count - 1);
        var points = new PointCollection(samples.Count);
        for (var index = 0; index < samples.Count; index++)
        {
            var x = width * index / denominator;
            var y = height - height * selector(samples[index]) / max;
            points.Add(new System.Windows.Point(x, y));
        }
        return points;
    }
    private async Task RefreshOverviewPeriodAsync(bool force)
    {
        if (_quitting) return;
        var nowUtc = DateTimeOffset.UtcNow;
        if (!force && nowUtc - _lastOverviewPeriodRefreshUtc < TimeSpan.FromSeconds(5)) return;
        if (_overviewPeriodQueryRunning)
        {
            if (force) Interlocked.Increment(ref _overviewPeriodQueryGeneration);
            return;
        }

        var generation = Interlocked.Increment(ref _overviewPeriodQueryGeneration);
        _overviewPeriodQueryRunning = true;
        var range = UsagePeriodResolver.Resolve(_selectedOverviewPeriod, nowUtc, TimeZoneInfo.Local);
        OverviewPeriodRangeText.Text = $"{range.FromUtc.ToLocalTime():dd/MM/yyyy HH:mm} - {range.ToUtc.ToLocalTime():dd/MM/yyyy HH:mm}";
        OverviewPeriodUpdatedText.Text = "Loading...";
        try
        {
            await _observability.FlushAsync(nowUtc);
            var globalTask = _observability.QueryExactPeriodAsync(range);
            var workspaceTasks = WorkspaceKeys.ToDictionary(
                key => key,
                key => _observability.QueryExactPeriodAsync(range, key),
                StringComparer.OrdinalIgnoreCase);
            await Task.WhenAll(workspaceTasks.Values.Append(globalTask));
            if (_quitting || generation != Volatile.Read(ref _overviewPeriodQueryGeneration)) return;

            ApplyOverviewUsage(await globalTask);
            foreach (var pair in workspaceTasks)
                ApplyOverviewWorkspacePeriodUsage(pair.Key, await pair.Value);
            _lastOverviewPeriodRefreshUtc = nowUtc;
            OverviewPeriodUpdatedText.Text = "Updated " + DateTimeOffset.Now.ToString("HH:mm:ss");
        }
        catch (ObjectDisposedException) { }
        catch (Exception ex)
        {
            if (generation == Volatile.Read(ref _overviewPeriodQueryGeneration))
                OverviewPeriodUpdatedText.Text = "Unavailable: " + ex.Message;
        }
        finally
        {
            _overviewPeriodQueryRunning = false;
        }
    }

    private void ApplyOverviewUsage(UsageCounters usage)
    {
        OverviewTokenInText.Text = FormatCount(usage.TokensInEst);
        OverviewTokenOutText.Text = FormatCount(usage.TokensOutEst);
        OverviewTokenTotalText.Text = FormatCount(usage.TotalTokensEst);
        OverviewInputBytesText.Text = FormatBytes(usage.RequestBytes);
        OverviewOutputBytesText.Text = FormatBytes(usage.ResponseBytes);
        OverviewTotalBytesText.Text = FormatBytes(usage.TotalPayloadBytes);
        OverviewToolCallsText.Text = FormatCount(usage.ToolCalls);
        OverviewExecutionTasksText.Text = FormatCount(usage.ExecutionTasks);
        OverviewReadCallsText.Text = FormatCount(usage.ReadCalls);
        OverviewWriteCallsText.Text = FormatCount(usage.WriteCalls);
        OverviewCommandCallsText.Text = FormatCount(usage.CommandCalls);
        OverviewGitCallsText.Text = FormatCount(usage.GitCalls);
        OverviewSkillCallsText.Text = FormatCount(usage.SkillCalls);
        OverviewErrorsText.Text = FormatCount(usage.Errors);
    }

    private void UpdateOverviewWorkspaceLive(string key, WorkspaceObservabilitySnapshot workspace, LocalMcpRuntimeHealthSnapshot health)
    {
        var status = OverviewStatusText(key);
        status.Text = health.RuntimeStatus switch
        {
            LocalMcpRuntimeStatus.Running => "Connected",
            LocalMcpRuntimeStatus.Restarting => "Reconnecting...",
            LocalMcpRuntimeStatus.Cooldown => "Reconnect cooldown",
            LocalMcpRuntimeStatus.Starting => "Connecting...",
            LocalMcpRuntimeStatus.Stopping => "Disconnecting...",
            LocalMcpRuntimeStatus.Failed => "Failed",
            _ => "Stopped",
        };
        status.Foreground = health.RuntimeStatus switch
        {
            LocalMcpRuntimeStatus.Running => System.Windows.Media.Brushes.ForestGreen,
            LocalMcpRuntimeStatus.Restarting or LocalMcpRuntimeStatus.Cooldown or LocalMcpRuntimeStatus.Starting or LocalMcpRuntimeStatus.Stopping => System.Windows.Media.Brushes.DarkOrange,
            LocalMcpRuntimeStatus.Failed => System.Windows.Media.Brushes.Firebrick,
            _ => System.Windows.Media.Brushes.Gray,
        };
        OverviewUptimeText(key).Text = workspace.RuntimeRunning ? "Uptime: " + FormatDuration(workspace.RuntimeUptime) : "Uptime: -";
        var nextRestart = health.RestartPending && health.NextRestartUtc.HasValue
            ? $" | next restart {Math.Max(0, (health.NextRestartUtc.Value - DateTimeOffset.UtcNow).TotalSeconds):N1}s"
            : "";
        var lastHealthOk = health.LastTunnelHealthSuccessUtc.HasValue
            ? $" | last OK {health.LastTunnelHealthSuccessUtc.Value.ToLocalTime():HH:mm:ss}"
            : "";
        var restartCount = health.TotalRestarts > 0 ? $" | restarts {health.TotalRestarts:N0}" : "";
        OverviewComponentHealthText(key).Text =
            $"MCP: {(health.LocalServerReady ? "ready" : "down")} | Tunnel: {(health.TunnelProcessRunning ? "running" : "down")} | Health: {FormatTunnelHealth(health.TunnelHealth)}{lastHealthOk}{restartCount}{nextRestart}";
    }

    private static string FormatTunnelHealth(TunnelHealthProbeState state) => state switch
    {
        TunnelHealthProbeState.Reachable => "reachable",
        TunnelHealthProbeState.Unreachable => "unreachable",
        TunnelHealthProbeState.NotConfigured => "dynamic/pending",
        _ => "unknown",
    };

    private void ApplyOverviewWorkspacePeriodUsage(string key, UsageCounters usage)
    {
        OverviewCallsText(key).Text = "Calls: " + FormatCount(usage.ToolCalls);
        OverviewTokensText(key).Text = "MCP tokens (est.): " + FormatCount(usage.TotalTokensEst);
    }

    private void RefreshObservedSessionsUi()
    {
        var selectedKey = (OverviewSessionsGrid.SelectedItem as ObservedSessionRow)?.Key;
        var rows = new List<ObservedSessionRow>();
        foreach (var session in _observability.Sessions.Snapshot())
        {
            var usage = session.Workspaces.Values.Select(value => value.Usage).Aggregate(default(UsageCounters), (sum, value) => sum + value);
            rows.Add(new ObservedSessionRow(
                "B:" + session.SessionHash,
                "Bound",
                session.State.ToString(),
                ShortHash(session.SessionHash),
                string.Join(",", session.Workspaces.Keys.OrderBy(key => key)),
                session.CreatedUtc,
                session.LastSeenUtc,
                usage.ToolCalls,
                usage.ExecutionTasks,
                usage.TotalTokensEst,
                usage.TotalPayloadBytes,
                usage.Errors));
        }
        foreach (var unbound in _observability.Sessions.UnboundSnapshot())
        {
            rows.Add(new ObservedSessionRow(
                "U:" + unbound.WorkspaceKey,
                "Unbound",
                unbound.State.ToString(),
                "unbound-" + unbound.WorkspaceKey,
                unbound.WorkspaceKey,
                unbound.FirstSeenUtc,
                unbound.LastSeenUtc,
                unbound.Usage.ToolCalls,
                unbound.Usage.ExecutionTasks,
                unbound.Usage.TotalTokensEst,
                unbound.Usage.TotalPayloadBytes,
                unbound.Usage.Errors));
        }
        rows = rows.OrderBy(row => row.State == nameof(LogicalSessionActivityState.Active) ? 0 : 1)
            .ThenByDescending(row => row.LastSeenUtc)
            .ToList();

        OverviewSessionSummaryText.Text = rows.Count == 0
            ? "No correlated AI chats yet. Unbound MCP traffic remains separate and is never counted as a chat."
            : $"{rows.Count(row => row.Kind == "Bound")} AI chat(s), {rows.Count(row => row.Kind == "Unbound")} unbound MCP activity bucket(s).";
        OverviewSessionsGrid.ItemsSource = rows;
        if (selectedKey is not null)
        {
            var selected = rows.FirstOrDefault(row => row.Key == selectedKey);
            if (selected is not null) OverviewSessionsGrid.SelectedItem = selected;
        }
    }

    private void OverviewSessionsGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (OverviewSessionsGrid.SelectedItem is not ObservedSessionRow row)
        {
            OverviewSessionDetailText.Text = "Select an AI chat or unbound activity row.";
            return;
        }
        OverviewSessionDetailText.Text =
            $"Type: {row.Kind} | State: {row.State} | Observed ID: {row.DisplayId} | Workspaces: {row.Workspaces}\n" +
            $"First seen: {row.FirstSeenUtc.ToLocalTime():dd/MM/yyyy HH:mm:ss} | Last seen: {row.LastSeenUtc.ToLocalTime():dd/MM/yyyy HH:mm:ss}\n" +
            $"Calls: {FormatCount(row.Calls)} | Tasks: {FormatCount(row.Tasks)} | MCP tokens est.: {FormatCount(row.Tokens)} | Payload: {FormatBytes(row.PayloadBytes)} | Errors: {FormatCount(row.Errors)}";
    }

    private static string ShortHash(string hash) => hash.Length <= 12 ? hash : hash[..12] + "...";

    private sealed record ObservedSessionRow(
        string Key,
        string Kind,
        string State,
        string DisplayId,
        string Workspaces,
        DateTimeOffset FirstSeenUtc,
        DateTimeOffset LastSeenUtc,
        long Calls,
        long Tasks,
        long Tokens,
        long PayloadBytes,
        long Errors)
    {
        public string LastSeen => LastSeenUtc.ToLocalTime().ToString("dd/MM HH:mm:ss");
    }

    private TextBlock OverviewStatusText(string key) => key switch
    {
        "C" => COverviewStatusText,
        "D" => DOverviewStatusText,
        "E" => EOverviewStatusText,
        "F" => FOverviewStatusText,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private TextBlock OverviewComponentHealthText(string key) => key switch
    {
        "C" => COverviewHealthText,
        "D" => DOverviewHealthText,
        "E" => EOverviewHealthText,
        "F" => FOverviewHealthText,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };
    private TextBlock OverviewUptimeText(string key) => key switch
    {
        "C" => COverviewUptimeText,
        "D" => DOverviewUptimeText,
        "E" => EOverviewUptimeText,
        "F" => FOverviewUptimeText,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private TextBlock OverviewCallsText(string key) => key switch
    {
        "C" => COverviewCallsText,
        "D" => DOverviewCallsText,
        "E" => EOverviewCallsText,
        "F" => FOverviewCallsText,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private TextBlock OverviewTokensText(string key) => key switch
    {
        "C" => COverviewTokensText,
        "D" => DOverviewTokensText,
        "E" => EOverviewTokensText,
        "F" => FOverviewTokensText,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private static string FormatCount(long value) => value.ToString("N0");

    private static string FormatBytes(long bytes)
    {
        if (bytes < 1_024) return $"{bytes:N0} B";
        if (bytes < 1_048_576) return $"{bytes / 1_024d:N1} KB";
        if (bytes < 1_073_741_824) return $"{bytes / 1_048_576d:N1} MB";
        return $"{bytes / 1_073_741_824d:N2} GB";
    }

    private static string FormatDuration(TimeSpan duration)
    {
        if (duration < TimeSpan.Zero) duration = TimeSpan.Zero;
        if (duration.TotalDays >= 1) return $"{(int)duration.TotalDays}d {duration.Hours:D2}h {duration.Minutes:D2}m";
        if (duration.TotalHours >= 1) return $"{(int)duration.TotalHours}h {duration.Minutes:D2}m {duration.Seconds:D2}s";
        return $"{duration.Minutes:D2}m {duration.Seconds:D2}s";
    }
    private FileMcpSettings LoadSettingsSafely()
    {
        try { return _settingsStore.Load(); }
        catch (Exception ex)
        {
            ShowOperationalError(
                "Settings unavailable",
                "Saved desktop settings could not be loaded.",
                "Local desktop settings",
                "Stored settings were not modified; defaults are being used for this launch.",
                "Review Settings before connecting or saving changes.",
                ex.GetType().Name);
            return new FileMcpSettings();
        }
    }

    private void ApplySettings(FileMcpSettings settings)
    {
        foreach (var key in WorkspaceKeys)
        {
            var workspace = settings.Workspaces.FirstOrDefault(item => item.Key.Equals(key, StringComparison.OrdinalIgnoreCase));
            if (workspace is null) continue;

            EnabledBox(key).IsChecked = workspace.Enabled;
            TunnelBox(key).Text = workspace.TunnelId;
            PathBox(key).Text = workspace.AllowedDirectory;
            ProfileBoxFor(key).Text = workspace.Profile;
            PortBoxFor(key).Text = workspace.Port.ToString();
            HealthBox(key).Text = workspace.HealthAddress;
        }

        GitNameBox.Text = settings.GitUserName;
        GitEmailBox.Text = settings.GitUserEmail;
        PolicyProfileComboBox.SelectedValue = settings.PolicyProfile;
        if (PolicyProfileComboBox.SelectedValue is null) PolicyProfileComboBox.SelectedValue = FileMcpPolicyProfiles.Restricted;
        EnableCommandsCheckBox.IsChecked = settings.PolicyProfile == FileMcpPolicyProfiles.LegacyCommandCompatible;
        ExecEnvironmentAllowListBox.Text = string.Join(", ", settings.ExecEnvironmentAllowList);
        UpdatePolicyExplanation();
        OtlpEnabledCheckBox.IsChecked = settings.OtlpEnabled;
        OtlpEndpointBox.Text = string.IsNullOrWhiteSpace(settings.OtlpEndpoint) ? OtlpTelemetrySettings.DefaultEndpoint : settings.OtlpEndpoint;
    }

    private void PolicyProfileComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        UpdatePolicyExplanation();
    }

    private void UpdatePolicyExplanation()
    {
        var profile = PolicyProfileComboBox.SelectedValue?.ToString() ?? FileMcpPolicyProfiles.Restricted;
        PolicyExplanationText.Text = profile switch
        {
            FileMcpPolicyProfiles.Restricted =>
                "Restricted keeps the legacy-safe surface. It does not grant shell or open-world network authority.",
            FileMcpPolicyProfiles.WorkspaceAuto =>
                "Workspace auto enables the safe workspace-oriented capability set while keeping shell and open-world network tools disabled.",
            FileMcpPolicyProfiles.Custom =>
                "Custom uses the explicit local policy configuration. Advanced authority remains constrained by the server-owned policy model.",
            FileMcpPolicyProfiles.LegacyCommandCompatible =>
                "Legacy command compatible is retained only for migrated configurations and cannot be selected for new policy changes.",
            _ => "Policy is owned by local settings and enforced by the server.",
        };
    }

    private void UpdateApiKeyStatus()
    {
        var saved = _credentialStore.HasSavedApiKey;
        ApiKeyStatusText.Text = saved ? "API key is saved in Windows Credential Manager" : "No API key is saved";
        DeleteApiKeyButton.IsEnabled = saved;
        ConnectionCredentialBadge.Status = saved ? PresentationStatus.Passed : PresentationStatus.Warning;
        UpdateConnectionExperience();
    }

    private void UpdateConnectionExperience()
    {
        if (!IsLoaded && ConnectionsHeader is null)
            return;

        var enabled = WorkspaceKeys.Where(key => EnabledBox(key).IsChecked == true).ToArray();
        var running = _runtimes.Values.Count(runtime => runtime.State.Status == LocalMcpRuntimeStatus.Running);
        var failed = _runtimes.Values.Count(runtime => runtime.State.Status == LocalMcpRuntimeStatus.Failed);

        ConnectionsHeader.Status = failed > 0
            ? PresentationStatus.Failed
            : running > 0 && running == enabled.Length
                ? PresentationStatus.Connected
                : running > 0
                    ? PresentationStatus.Degraded
                    : PresentationStatus.Stopped;

        var configuredTunnels = enabled.Count(key => !string.IsNullOrWhiteSpace(TunnelBox(key).Text));
        ConnectionDiagnosticsText.Text =
            $"{running} connected / {enabled.Length} enabled workspace(s); " +
            $"{configuredTunnels} tunnel ID(s) configured; " +
            (_credentialStore.HasSavedApiKey ? "credential stored securely." : "credential missing.");
    }

    private async void Connect_Click(object sender, RoutedEventArgs e)
    {
        if (_runtimes.Values.Any(runtime => runtime.State.Status is LocalMcpRuntimeStatus.Running or LocalMcpRuntimeStatus.Restarting or LocalMcpRuntimeStatus.Cooldown or LocalMcpRuntimeStatus.Starting or LocalMcpRuntimeStatus.Stopping))
        {
            await StopAllAsync();
            return;
        }

        if (!ValidateConnection(requireApiKey: true) || !ValidateSettings()) return;

        try
        {
            SaveTypedApiKeyIfPresent();
            SaveAllSettings();
            var apiKey = _credentialStore.ReadApiKey();

            foreach (var workspace in _settings.Workspaces.Where(item => item.Enabled))
            {
                var runtime = _runtimes[workspace.Key];
                await runtime.StartAsync(BuildConfiguration(workspace, apiKey));
            }

            RefreshRuntimeUi();
        }
        catch (Exception ex)
        {
            ShowOperationalError(
                "Connection failed",
                "One or more configured runtimes could not be started.",
                "Enabled workspace runtimes",
                "Runtime state may be partial; current runtime status remains authoritative.",
                "Open Connections, inspect each runtime state, then retry after resolving the reported condition.",
                ex.GetType().Name);
        }
    }

    private void SaveConnection_Click(object sender, RoutedEventArgs e)
    {
        if (!ValidateConnection(requireApiKey: true)) return;

        try
        {
            SaveTypedApiKeyIfPresent();
            SaveConnectionFields();
            _settingsStore.Save(_settings);
            UpdateApiKeyStatus();
            RefreshOnboardingExperience();
            AppendLog("Connection settings saved.\n");

            if (_runtimes.Values.Any(runtime => runtime.State.Status != LocalMcpRuntimeStatus.Stopped))
                AppendLog("Connection changes will take effect after the affected workspace reconnects.\n");
        }
        catch (Exception ex)
        {
            ShowOperationalError(
                "Connection settings not confirmed",
                "Connection settings could not be persisted completely.",
                "Local connection settings and secure credential state",
                "Credential or local fields may have partially changed; persisted state is not confirmed.",
                "Review Connection status and settings before retrying.",
                ex.GetType().Name);
        }
    }

    private void SaveSettings_Click(object sender, RoutedEventArgs e)
    {
        if (!ValidateSettings()) return;

        try
        {
            SaveSettingsFields();
            _settingsStore.Save(_settings);
            AppendLog("Workspace settings saved.\n");
            RefreshOnboardingExperience();

            if (_runtimes.Values.Any(runtime => runtime.State.Status != LocalMcpRuntimeStatus.Stopped))
                AppendLog("Workspace changes will take effect after the affected workspace reconnects.\n");

            RefreshRuntimeUi();
        }
        catch (Exception ex)
        {
            ShowOperationalError(
                "Workspace settings not confirmed",
                "Workspace settings could not be persisted completely.",
                "Local workspace settings",
                "In-memory fields may differ from persisted settings; saved state is not confirmed.",
                "Review Settings and save again after resolving the reported condition.",
                ex.GetType().Name);
        }
    }

    private void DeleteApiKey_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            _credentialStore.DeleteApiKey();
            ApiKeyBox.Password = "";
            UpdateApiKeyStatus();
        }
        catch (Exception ex)
        {
            ShowOperationalError(
                "Credential removal not confirmed",
                "The saved runtime credential could not be removed completely.",
                "Secure runtime credential storage",
                "Credential removal is not confirmed.",
                "Check the saved-credential status before retrying.",
                ex.GetType().Name);
        }
    }

    private void BrowseDirectory_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not System.Windows.Controls.Button button || button.Tag is not string key || !WorkspaceKeys.Contains(key))
            return;

        var pathBox = PathBox(key);
        var initialDirectory = Directory.Exists(pathBox.Text)
            ? pathBox.Text
            : key == "C"
                ? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)
                : key + @":\";

        var dialog = new OpenFolderDialog
        {
            Title = $"Choose shared directory for drive {key}",
            Multiselect = false,
            InitialDirectory = initialDirectory,
        };

        if (dialog.ShowDialog(this) == true)
            pathBox.Text = dialog.FolderName;
    }

    private async void Quit_Click(object sender, RoutedEventArgs e) => await QuitAsync();

    private bool ValidateConnection(bool requireApiKey)
    {
        var enabled = WorkspaceKeys.Where(key => EnabledBox(key).IsChecked == true).ToArray();
        if (enabled.Length == 0)
        {
            MainTabs.SelectedItem = SettingsTab;
            ShowError("Enable at least one workspace in Settings.");
            return false;
        }

        foreach (var key in enabled)
        {
            var tunnelId = TunnelBox(key).Text.Trim();
            if (tunnelId.Length == 0)
            {
                MainTabs.SelectedItem = ConnectionTab;
                ShowError($"Enter a Tunnel ID for drive {key}.");
                return false;
            }

            if (!LocalMcpRuntime.IsValidTunnelId(tunnelId))
            {
                MainTabs.SelectedItem = ConnectionTab;
                ShowError($"Drive {key}: Tunnel ID must match tunnel_<32 lowercase letters or digits>.");
                return false;
            }
        }

        if (requireApiKey && ApiKeyBox.Password.Trim().Length == 0 && !_credentialStore.HasSavedApiKey)
        {
            MainTabs.SelectedItem = ConnectionTab;
            ShowError("Enter a Runtime API key in the Connection tab.");
            return false;
        }

        return true;
    }

    private bool ValidateSettings()
    {
        var enabledKeys = new List<string>();
        var usedPorts = new HashSet<int>();
        var usedProfiles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var key in WorkspaceKeys)
        {
            var enabled = EnabledBox(key).IsChecked == true;
            if (enabled) enabledKeys.Add(key);

            var path = PathBox(key).Text.Trim();
            var profile = ProfileBoxFor(key).Text.Trim();
            var health = HealthBox(key).Text.Trim();

            if (!LocalMcpRuntime.IsValidProfileName(profile))
            {
                MainTabs.SelectedItem = SettingsTab;
                AdvancedExpander.IsExpanded = true;
                ShowError($"Drive {key}: profile must start with a letter or number and contain only letters, numbers, '.', '_' or '-' (maximum 128 characters).");
                return false;
            }

            if (!int.TryParse(PortBoxFor(key).Text.Trim(), out var port) || port is < 1 or > 65535)
            {
                MainTabs.SelectedItem = SettingsTab;
                AdvancedExpander.IsExpanded = true;
                ShowError($"Drive {key}: MCP port must be between 1 and 65535.");
                return false;
            }

            if (LocalMcpRuntime.NormalizeHealthAddress(health) is null)
            {
                MainTabs.SelectedItem = SettingsTab;
                AdvancedExpander.IsExpanded = true;
                ShowError($"Drive {key}: health listener must use localhost, 127.0.0.1, or [::1] with a port from 0 to 65535.");
                return false;
            }

            if (!enabled) continue;

            if (path.Length == 0 || !Directory.Exists(path))
            {
                MainTabs.SelectedItem = SettingsTab;
                ShowError($"Drive {key}: choose an existing shared directory.");
                return false;
            }

            if (!PathBelongsToDrive(path, key))
            {
                MainTabs.SelectedItem = SettingsTab;
                ShowError($"Drive {key}: the shared directory must be located on drive {key}:.");
                return false;
            }

            if (!usedPorts.Add(port))
            {
                MainTabs.SelectedItem = SettingsTab;
                AdvancedExpander.IsExpanded = true;
                ShowError($"Drive {key}: MCP port {port} is already used by another enabled workspace.");
                return false;
            }

            if (!usedProfiles.Add(profile))
            {
                MainTabs.SelectedItem = SettingsTab;
                AdvancedExpander.IsExpanded = true;
                ShowError($"Drive {key}: profile '{profile}' is already used by another enabled workspace.");
                return false;
            }
        }

        if (OtlpEnabledCheckBox.IsChecked == true)
        {
            try { _ = OtlpTelemetrySettings.NormalizeBaseEndpoint(OtlpEndpointBox.Text); }
            catch (Exception ex) when (ex is FileMcpException or UriFormatException)
            {
                MainTabs.SelectedItem = SettingsTab;
                AdvancedExpander.IsExpanded = true;
                ShowOperationalError(
                    "Telemetry settings invalid",
                    "The OTLP endpoint could not be validated.",
                    "Advanced telemetry settings",
                    "No telemetry setting was saved by this validation.",
                    "Correct the endpoint and validate again.",
                    ex.GetType().Name);
                return false;
            }
        }

        if (enabledKeys.Count == 0)
        {
            MainTabs.SelectedItem = SettingsTab;
            ShowError("Enable at least one workspace.");
            return false;
        }

        return true;
    }

    private static bool PathBelongsToDrive(string path, string key)
    {
        try
        {
            var root = Path.GetPathRoot(Path.GetFullPath(path));
            return !string.IsNullOrWhiteSpace(root) &&
                   root.Length >= 2 &&
                   char.ToUpperInvariant(root[0]) == key[0] &&
                   root[1] == ':';
        }
        catch
        {
            return false;
        }
    }

    private void SaveTypedApiKeyIfPresent()
    {
        var typedKey = ApiKeyBox.Password.Trim();
        if (typedKey.Length == 0) return;

        _credentialStore.SaveApiKey(typedKey);
        ApiKeyBox.Password = "";
        UpdateApiKeyStatus();
    }

    private void SaveAllSettings()
    {
        SaveConnectionFields();
        SaveSettingsFields();
        _settingsStore.Save(_settings);
    }

    private void SaveConnectionFields()
    {
        foreach (var key in WorkspaceKeys)
            Workspace(key).TunnelId = TunnelBox(key).Text.Trim();
    }

    private void SaveSettingsFields()
    {
        foreach (var key in WorkspaceKeys)
        {
            var workspace = Workspace(key);
            workspace.Enabled = EnabledBox(key).IsChecked == true;
            workspace.AllowedDirectory = PathBox(key).Text.Trim();
            workspace.Profile = ProfileBoxFor(key).Text.Trim();
            workspace.Port = int.Parse(PortBoxFor(key).Text.Trim());
            workspace.HealthAddress = HealthBox(key).Text.Trim();
        }

        _settings.GitUserName = GitNameBox.Text.Trim();
        _settings.GitUserEmail = GitEmailBox.Text.Trim();
        _settings.PolicyProfile = PolicyProfileComboBox.SelectedValue as string ?? FileMcpPolicyProfiles.Restricted;
        _settings.EnableCommands = _settings.PolicyProfile == FileMcpPolicyProfiles.LegacyCommandCompatible;
        _settings.ExecEnvironmentAllowList = ParseEnvironmentAllowList(ExecEnvironmentAllowListBox.Text);
        _settings.OtlpEnabled = OtlpEnabledCheckBox.IsChecked == true;
        var otlpEndpoint = OtlpEndpointBox.Text.Trim();
        _settings.OtlpEndpoint = otlpEndpoint.Length == 0 ? OtlpTelemetrySettings.DefaultEndpoint : otlpEndpoint;
        ConfigureOtlpFromSettings();
    }

    private void ConfigureOtlpFromSettings()
    {
        var endpoint = string.IsNullOrWhiteSpace(_settings.OtlpEndpoint)
            ? OtlpTelemetrySettings.DefaultEndpoint
            : _settings.OtlpEndpoint.Trim();
        _ = _observability.ConfigureOtlp(new OtlpTelemetrySettings(_settings.OtlpEnabled, endpoint));
    }

    private LocalMcpConfiguration BuildConfiguration(FileMcpWorkspaceSettings workspace, string apiKey) =>
        new(
            workspace.TunnelId,
            apiKey,
            workspace.Profile,
            checked((ushort)workspace.Port),
            workspace.AllowedDirectory,
            workspace.HealthAddress,
            _settings.GitUserName,
            _settings.GitUserEmail,
            _settings.EnableCommands,
            new LocalPolicyConfiguration
            {
                Profile = _settings.PolicyProfile,
                CustomMaxRisk = _settings.CustomPolicyMaxRisk,
                CustomAllowedEffects = _settings.CustomPolicyAllowedEffects,
                CustomAllowNetworkOpenWorld = _settings.CustomPolicyAllowNetworkOpenWorld,
                CustomAllowShell = _settings.CustomPolicyAllowShell,
            },
            _settings.ExecEnvironmentAllowList,
            BuildDockerExecutionBackendConfiguration());

    private DockerExecutionBackendConfiguration? BuildDockerExecutionBackendConfiguration()
    {
        if (!string.Equals(_settings.ExecutionBackendMode, "docker", StringComparison.OrdinalIgnoreCase))
            return null;

        return new DockerExecutionBackendConfiguration
        {
            Enabled = true,
            Image = _settings.DockerImage,
            AllowedImages = _settings.DockerAllowedImages.ToList(),
            NetworkEnabled = _settings.DockerNetworkEnabled,
            CpuLimit = _settings.DockerCpuLimit,
            MemoryBytes = checked((long)_settings.DockerMemoryMb * 1024 * 1024),
            PidsLimit = _settings.DockerPidsLimit,
            User = _settings.DockerUser,
            StartupTimeoutSeconds = _settings.DockerStartupTimeoutSeconds,
            IdleTtlSeconds = _settings.DockerIdleTtlSeconds,
            MaxLifetimeSeconds = _settings.DockerMaxLifetimeSeconds,
        };
    }
    private static List<string> ParseEnvironmentAllowList(string value) => value
        .Split(new[] { ',', ';', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
        .Where(item => item.Length > 0)
        .ToList();

    private async Task StopAllAsync()
    {
        var tasks = _runtimes.Values
            .Where(runtime => runtime.State.Status != LocalMcpRuntimeStatus.Stopped)
            .Select(runtime => runtime.StopAsync())
            .ToArray();

        if (tasks.Length > 0)
            await Task.WhenAll(tasks);

        RefreshRuntimeUi();
    }

    private void UpdateRuntimeState(string key, LocalMcpRuntimeState state)
    {
        UpdateWorkspaceStatus(key, state);
        UpdateConnectButton();
        UpdateShellContext();
        RefreshOnboardingExperience();

        if (state.Status == LocalMcpRuntimeStatus.Failed && !string.IsNullOrEmpty(state.Error))
            ShowOperationalError(
                "Runtime failed",
                "The workspace runtime reported a failure.",
                $"Drive {key}",
                "This workspace is Failed; other workspace states are unchanged.",
                "Open Connections and inspect current runtime diagnostics before retrying.",
                state.Error);
    }

    private void RefreshRuntimeUi()
    {
        foreach (var key in WorkspaceKeys)
            UpdateWorkspaceStatus(key, _runtimes.TryGetValue(key, out var runtime) ? runtime.State : LocalMcpRuntimeState.Stopped);

        UpdateConnectButton();
        UpdateShellContext();
        UpdateConnectionExperience();
        RefreshOnboardingExperience();
        if (MainTabs.SelectedItem == WorkspacesTab) RefreshWorkspaceRows();
    }

    private void InitializeOnboardingExperience()
    {
        if (!_settings.OnboardingCompleted && HasExistingConfiguredSetup())
        {
            _settings.OnboardingCompleted = true;
            try { _settingsStore.Save(_settings); }
            catch (Exception ex) { AppendLog($"[Setup] Could not persist legacy onboarding migration: {ex.Message}\n"); }
        }

        RefreshOnboardingExperience();
        if (!_settings.OnboardingCompleted)
            MainTabs.SelectedItem = OnboardingTab;
    }

    private bool HasExistingConfiguredSetup() =>
        _credentialStore.HasSavedApiKey &&
        _settings.Workspaces.Any(workspace =>
            workspace.Enabled &&
            LocalMcpRuntime.IsValidTunnelId(workspace.TunnelId?.Trim() ?? "") &&
            !string.IsNullOrWhiteSpace(workspace.AllowedDirectory) &&
            Directory.Exists(workspace.AllowedDirectory));

    private bool AllEnabledWorkspacesRunning()
    {
        var enabled = WorkspaceKeys.Where(key => EnabledBox(key).IsChecked == true).ToArray();
        return enabled.Length > 0 && enabled.All(key => _runtimes.TryGetValue(key, out var runtime) && runtime.State.Status == LocalMcpRuntimeStatus.Running);
    }

    private void RefreshOnboardingExperience()
    {
        if (OnboardingWorkspaceStatusText is null) return;
        var enabled = WorkspaceKeys.Where(key => EnabledBox(key).IsChecked == true).ToArray();
        var workspaceReady = enabled.Length > 0 && enabled.All(key =>
        {
            var path = PathBox(key).Text.Trim();
            return path.Length > 0 && Directory.Exists(path) && PathBelongsToDrive(path, key);
        });
        var policy = PolicyProfileComboBox.SelectedValue?.ToString() ?? FileMcpPolicyProfiles.Restricted;
        var credentialReady = _credentialStore.HasSavedApiKey || ApiKeyBox.Password.Trim().Length > 0;
        var tunnelsReady = enabled.Length > 0 && enabled.All(key => LocalMcpRuntime.IsValidTunnelId(TunnelBox(key).Text.Trim()));
        var running = enabled.Count(key => _runtimes.TryGetValue(key, out var runtime) && runtime.State.Status == LocalMcpRuntimeStatus.Running);
        var allRunning = enabled.Length > 0 && running == enabled.Length;

        NavOnboardingButton.Visibility = _settings.OnboardingCompleted ? Visibility.Collapsed : Visibility.Visible;
        OnboardingWorkspaceStatusText.Text = workspaceReady
            ? $"Ready: {enabled.Length} enabled workspace(s) with existing roots."
            : "Choose at least one enabled workspace with an existing root.";
        OnboardingPolicyStatusText.Text = $"Server-enforced profile: {policy}.";
        OnboardingCredentialStatusText.Text = credentialReady && tunnelsReady
            ? "Ready: credential present and every enabled workspace has a valid Tunnel ID."
            : "Incomplete: store the runtime API key securely and configure valid Tunnel IDs.";
        OnboardingConnectionStatusText.Text = allRunning
            ? $"PASS: {running}/{enabled.Length} enabled runtime(s) report Running."
            : $"Not passed: {running}/{enabled.Length} enabled runtime(s) report Running.";
        OnboardingTestButton.IsEnabled = workspaceReady && credentialReady && tunnelsReady;
        OnboardingFinishButton.IsEnabled = allRunning;
        OnboardingSummaryText.Text = allRunning
            ? "Connection test passed against live runtime state. Finish setup to continue to Home."
            : "Complete workspace, policy and connection settings, then test the real runtime connection.";
    }

    private void NavigateOnboarding_Click(object sender, RoutedEventArgs e)
    {
        RefreshOnboardingExperience();
        MainTabs.SelectedItem = OnboardingTab;
    }

    private void OnboardingWorkspace_Click(object sender, RoutedEventArgs e) => MainTabs.SelectedItem = SettingsTab;
    private void OnboardingPolicy_Click(object sender, RoutedEventArgs e) => MainTabs.SelectedItem = SettingsTab;
    private void OnboardingConnection_Click(object sender, RoutedEventArgs e) => MainTabs.SelectedItem = ConnectionTab;

    private void OnboardingTestConnection_Click(object sender, RoutedEventArgs e)
    {
        RefreshOnboardingExperience();
        if (AllEnabledWorkspacesRunning()) return;
        var active = _runtimes.Values.Any(runtime => runtime.State.Status is LocalMcpRuntimeStatus.Running or LocalMcpRuntimeStatus.Restarting or LocalMcpRuntimeStatus.Cooldown or LocalMcpRuntimeStatus.Starting or LocalMcpRuntimeStatus.Stopping);
        if (active)
        {
            ShowError("Connection test uses current runtime truth. Resolve the current partial/transitioning runtime state in Connections before testing again.");
            return;
        }
        OnboardingConnectionStatusText.Text = "Testing: starting the configured runtime(s)...";
        Connect_Click(sender, e);
    }

    private void OnboardingFinish_Click(object sender, RoutedEventArgs e)
    {
        RefreshOnboardingExperience();
        if (!AllEnabledWorkspacesRunning())
        {
            ShowError("Finish setup is available only after every enabled runtime reports Running.");
            return;
        }
        _settings.OnboardingCompleted = true;
        _settingsStore.Save(_settings);
        RefreshOnboardingExperience();
        MainTabs.SelectedItem = OverviewTab;
    }

    private void UpdateShellContext()
    {
        var connected = _runtimes.Values.Count(runtime => runtime.State.Status == LocalMcpRuntimeStatus.Running);
        var active = WorkspaceKeys.Where(key => EnabledBox(key).IsChecked == true).ToArray();        ShellStatusBadge.Status = connected switch
        {
            0 => PresentationStatus.Stopped,
            _ when connected == active.Length && active.Length > 0 => PresentationStatus.Healthy,
            _ => PresentationStatus.Degraded,
        };

        ShellWorkspaceText.Text = active.Length == 0
            ? "No workspace enabled"
            : "Workspaces " + string.Join(" Â· ", active);
    }

    private void NavigateHome_Click(object sender, RoutedEventArgs e) => MainTabs.SelectedItem = OverviewTab;
    private void NavigateWorkspaces_Click(object sender, RoutedEventArgs e)
    {
        MainTabs.SelectedItem = WorkspacesTab;
        RefreshWorkspaceRows();
    }
    private void NavigateConnections_Click(object sender, RoutedEventArgs e) => MainTabs.SelectedItem = ConnectionTab;
    private void NavigateSettings_Click(object sender, RoutedEventArgs e) => MainTabs.SelectedItem = SettingsTab;
    private void NavigateActivity_Click(object sender, RoutedEventArgs e)
    {
        MainTabs.SelectedItem = ActivityTab;
        RefreshActivityGrid();
    }
    private void NavigateChanges_Click(object sender, RoutedEventArgs e)
    {
        MainTabs.SelectedItem = ChangesTab;
        RefreshChangesGrid();
    }
    private void NavigateEvidence_Click(object sender, RoutedEventArgs e)
    {
        MainTabs.SelectedItem = EvidenceTab;
        RefreshEvidenceGrid();
    }
    private void NavigateRepository_Click(object sender, RoutedEventArgs e)
    {
        MainTabs.SelectedItem = RepositoryTab;
        RefreshRepositoryGrid();
    }
    private async void NavigateTerminal_Click(object sender, RoutedEventArgs e)
    {
        MainTabs.SelectedItem = TerminalTab;
        await RefreshTerminalAsync(readSelectedOutput: true);
    }
    private async void NavigateRecovery_Click(object sender, RoutedEventArgs e)
    {
        MainTabs.SelectedItem = RecoveryTab;
        await RefreshRecoveryAsync();
    }
    private void NavigateArtifacts_Click(object sender, RoutedEventArgs e)
    {
        MainTabs.SelectedItem = ArtifactsTab;
        RefreshArtifactBatchGrid();
    }
    private void NavigateBackend_Click(object sender, RoutedEventArgs e)
    {
        MainTabs.SelectedItem = BackendTab;
        RefreshBackendGrid();
    }
    private void NavigateDiagnostics_Click(object sender, RoutedEventArgs e)
    {
        MainTabs.SelectedIndex = MainTabs.Items.Count - 1;
        ApplyTextPreservingLiveTail(LogBox, _logBuffer);
    }

    private void CompactNavigation_Click(object sender, RoutedEventArgs e)
    {
        _navigationCompact = !_navigationCompact;
        NavigationColumn.Width = new GridLength(_navigationCompact ? 72 : 188);
        NavigationBrand.Visibility = _navigationCompact ? Visibility.Collapsed : Visibility.Visible;
        CompactNavigationButton.Content = _navigationCompact ? "Expand" : "Collapse";

        SetNavigationButtonPresentation(NavHomeButton, "Home", "H");
        SetNavigationButtonPresentation(NavWorkspacesButton, "Workspaces", "W");
        SetNavigationButtonPresentation(NavConnectionsButton, "Connections", "C");
        SetNavigationButtonPresentation(NavSettingsButton, "Settings", "S");
        SetNavigationButtonPresentation(NavActivityButton, "Activity", "A");
        SetNavigationButtonPresentation(NavChangesButton, "Changes", "C");
        SetNavigationButtonPresentation(NavEvidenceButton, "Evidence", "E");
        SetNavigationButtonPresentation(NavRepositoryButton, "Repository", "R");
        SetNavigationButtonPresentation(NavTerminalButton, "Terminal", "T");
        SetNavigationButtonPresentation(NavRecoveryButton, "Recovery", "Y");
        SetNavigationButtonPresentation(NavArtifactsButton, "Artifacts", "B");
        SetNavigationButtonPresentation(NavBackendButton, "Backend", "K");
        SetNavigationButtonPresentation(NavDiagnosticsButton, "Diagnostics", "D");

        ShellWorkspaceText.Visibility = _navigationCompact ? Visibility.Collapsed : Visibility.Visible;
    }

    private void SetNavigationButtonPresentation(System.Windows.Controls.Button button, string fullLabel, string compactLabel)
    {
        button.Content = _navigationCompact ? compactLabel : fullLabel;
        button.HorizontalContentAlignment = _navigationCompact ? System.Windows.HorizontalAlignment.Center : System.Windows.HorizontalAlignment.Left;
        button.ToolTip = _navigationCompact ? fullLabel : null;
    }

    private void RefreshWorkspaceRows()
    {
        foreach (var key in WorkspaceKeys)
        {
            var button = key switch
            {
                "C" => WorkspaceCRow,
                "D" => WorkspaceDRow,
                "E" => WorkspaceERow,
                "F" => WorkspaceFRow,
                _ => throw new ArgumentOutOfRangeException(nameof(key)),
            };
            var enabled = EnabledBox(key).IsChecked == true;
            var state = _runtimes[key].State.Status;
            var stateText = enabled ? state.ToString() : "Disabled";
            var root = PathBox(key).Text.Trim();
            button.Content = $"Drive {key}  |  {stateText}" + (root.Length == 0 ? string.Empty : $"  |  {root}");
        }
    }

    private void WorkspaceRow_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not System.Windows.Controls.Button button || button.Tag is not string key)
            return;

        var enabled = EnabledBox(key).IsChecked == true;
        var state = _runtimes[key].State.Status;
        WorkspaceDetailTitle.Text = $"Drive {key}";
        WorkspaceDetailRoot.Text = string.IsNullOrWhiteSpace(PathBox(key).Text) ? "Not configured" : PathBox(key).Text.Trim();
        WorkspaceDetailPolicy.Text = string.IsNullOrWhiteSpace(ProfileBoxFor(key).Text) ? "Default" : ProfileBoxFor(key).Text.Trim();
        WorkspaceDetailConnection.Text = enabled
            ? $"{state} | {TunnelBox(key).Text.Trim()}"
            : "Disabled";
        WorkspaceDetailActivity.Text = OverviewStatusText(key).Text;
        WorkspaceDetailStatus.Status = !enabled
            ? PresentationStatus.Unavailable
            : state switch
            {
                LocalMcpRuntimeStatus.Running => PresentationStatus.Healthy,
                LocalMcpRuntimeStatus.Failed => PresentationStatus.Failed,
                LocalMcpRuntimeStatus.Starting or LocalMcpRuntimeStatus.Restarting => PresentationStatus.Starting,
                _ => PresentationStatus.Stopped,
            };
    }

    private void UpdateWorkspaceStatus(string key, LocalMcpRuntimeState state)
    {
        var status = StatusText(key);
        var enabled = EnabledBox(key).IsChecked == true;

        if (!enabled && state.Status == LocalMcpRuntimeStatus.Stopped)
        {
            status.Text = "Disabled";
            status.Foreground = System.Windows.Media.Brushes.Gray;
            return;
        }

        switch (state.Status)
        {
            case LocalMcpRuntimeStatus.Stopped:
                status.Text = "Stopped";
                status.Foreground = System.Windows.Media.Brushes.Gray;
                break;
            case LocalMcpRuntimeStatus.Starting:
                status.Text = "Connecting...";
                status.Foreground = System.Windows.Media.Brushes.DarkOrange;
                break;
            case LocalMcpRuntimeStatus.Running:
                status.Text = "Connected";
                status.Foreground = System.Windows.Media.Brushes.ForestGreen;
                break;
            case LocalMcpRuntimeStatus.Restarting:
                status.Text = "Reconnecting...";
                status.Foreground = System.Windows.Media.Brushes.DarkOrange;
                break;
            case LocalMcpRuntimeStatus.Cooldown:
                status.Text = "Reconnect cooldown";
                status.Foreground = System.Windows.Media.Brushes.DarkOrange;
                break;
            case LocalMcpRuntimeStatus.Stopping:
                status.Text = "Disconnecting...";
                status.Foreground = System.Windows.Media.Brushes.DarkOrange;
                break;
            case LocalMcpRuntimeStatus.Failed:
                status.Text = "Failed";
                status.Foreground = System.Windows.Media.Brushes.Firebrick;
                break;
        }
    }

    private void UpdateConnectButton()
    {
        var states = _runtimes.Values.Select(runtime => runtime.State.Status).ToArray();

        if (states.Any(status => status is LocalMcpRuntimeStatus.Starting or LocalMcpRuntimeStatus.Stopping))
        {
            ConnectButton.Content = states.Any(status => status == LocalMcpRuntimeStatus.Starting) ? "Connecting..." : "Disconnecting...";
            ConnectButton.IsEnabled = false;
            return;
        }

        if (states.Any(status => status is LocalMcpRuntimeStatus.Running or LocalMcpRuntimeStatus.Restarting or LocalMcpRuntimeStatus.Cooldown))
        {
            ConnectButton.Content = "Disconnect all";
            ConnectButton.IsEnabled = true;
            return;
        }

        ConnectButton.Content = "Connect all";
        ConnectButton.IsEnabled = true;
    }

    private FileMcpWorkspaceSettings Workspace(string key) =>
        _settings.Workspaces.First(item => item.Key.Equals(key, StringComparison.OrdinalIgnoreCase));

    private System.Windows.Controls.CheckBox EnabledBox(string key) => key switch
    {
        "C" => CEnabledCheckBox,
        "D" => DEnabledCheckBox,
        "E" => EEnabledCheckBox,
        "F" => FEnabledCheckBox,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private System.Windows.Controls.TextBox TunnelBox(string key) => key switch
    {
        "C" => CTunnelIdBox,
        "D" => DTunnelIdBox,
        "E" => ETunnelIdBox,
        "F" => FTunnelIdBox,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private System.Windows.Controls.TextBox PathBox(string key) => key switch
    {
        "C" => CPathBox,
        "D" => DPathBox,
        "E" => EPathBox,
        "F" => FPathBox,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private System.Windows.Controls.TextBox ProfileBoxFor(string key) => key switch
    {
        "C" => CProfileBox,
        "D" => DProfileBox,
        "E" => EProfileBox,
        "F" => FProfileBox,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private System.Windows.Controls.TextBox PortBoxFor(string key) => key switch
    {
        "C" => CPortBox,
        "D" => DPortBox,
        "E" => EPortBox,
        "F" => FPortBox,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private System.Windows.Controls.TextBox HealthBox(string key) => key switch
    {
        "C" => CHealthBox,
        "D" => DHealthBox,
        "E" => EHealthBox,
        "F" => FHealthBox,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private System.Windows.Controls.TextBlock StatusText(string key) => key switch
    {
        "C" => CStatusText,
        "D" => DStatusText,
        "E" => EStatusText,
        "F" => FStatusText,
        _ => throw new ArgumentOutOfRangeException(nameof(key)),
    };

    private sealed record RecoveryQuarantineRow(
        string Workspace,
        string QuarantineRef,
        string OriginalPath,
        string State,
        bool IsTree,
        bool Expired,
        long CreatedEpochMs,
        long ExpiresEpochMs,
        int EntryCount,
        long TotalBytes,
        string? LastRestoreTarget,
        string? RecoveryRef)
    {
        public string Key => $"{Workspace}|{QuarantineRef}";
        public string ExpiryDisplay => ExpiresEpochMs <= 0 ? "-" : DateTimeOffset.FromUnixTimeMilliseconds(ExpiresEpochMs).ToLocalTime().ToString("MM-dd HH:mm");
        public bool CanRestore => !Expired && (string.Equals(State, "quarantined", StringComparison.OrdinalIgnoreCase) || string.Equals(State, "prepared", StringComparison.OrdinalIgnoreCase));
    }

    private sealed record RecoveryCheckpointRow(
        string Workspace,
        string CheckpointRef,
        string RepositoryPath,
        string? HeadOid,
        string SourceStateId,
        bool Expired,
        long CreatedEpochMs,
        long ExpiresEpochMs,
        int EntryCount,
        long TotalBytes,
        int StagedCount,
        int UnstagedCount,
        int UntrackedCount,
        int IgnoredCount,
        int ExcludedCount)
    {
        public string Key => $"{Workspace}|{CheckpointRef}";
        public string ExpiryDisplay => ExpiresEpochMs <= 0 ? "-" : DateTimeOffset.FromUnixTimeMilliseconds(ExpiresEpochMs).ToLocalTime().ToString("MM-dd HH:mm");
        public bool CanPlan => !Expired;
    }

    private sealed record BackendStatusRow(
        string Workspace,
        string BackendId,
        string BackendVersion,
        bool Available,
        string State,
        bool IsolationActive,
        bool DockerSelected,
        string DockerAvailability,
        string WorkspaceMode,
        string EnvironmentMode,
        string NetworkMode,
        string ResourceMode,
        string Capabilities,
        string ImageDigest,
        string NetworkPolicy,
        string ResourcePolicy)
    {
        public string Key => Workspace;
        public string BackendDisplay => $"{BackendId} {BackendVersion}";
        public string StateDisplay => $"{State}{(Available ? "" : " / unavailable")}";
        public string IsolationDisplay => IsolationActive ? "isolated" : "host";
        public string DockerDisplay => DockerSelected ? DockerAvailability : "not selected";
    }

    private sealed record TerminalSessionRow(
        string Workspace,
        string SessionId,
        int? Pid,
        string State,
        long LastActivityEpochMs,
        string EarliestCursor,
        string EndCursor,
        int? ExitCode,
        int SpillRefCount,
        bool ActualPty,
        bool RestartResumeSupported,
        bool GrantsAuthority,
        string BackendId,
        string BackendVersion,
        string BackendCapabilities,
        string PolicyProfile,
        long PolicyGeneration,
        string PolicyHash)
    {
        public string Key => $"{Workspace}|{SessionId}";
        public string PidDisplay => Pid?.ToString() ?? "-";
        public string LastActivityDisplay => LastActivityEpochMs <= 0
            ? "-"
            : DateTimeOffset.FromUnixTimeMilliseconds(LastActivityEpochMs).ToLocalTime().ToString("HH:mm:ss");
        public bool IsControllable => string.Equals(State, "running", StringComparison.OrdinalIgnoreCase);
    }

    private sealed record RepositoryItemRow(
        string Path,
        string Name,
        string Kind,
        string Detail,
        string ScoreDisplay);

    private sealed record RepositoryResultRow(
        DateTimeOffset Timestamp,
        string Workspace,
        string QueryKind,
        string ProviderId,
        string ProviderVersion,
        string Completeness,
        string SourceStateId,
        bool GrantsAuthority,
        bool RawSourcePersisted,
        bool Partial,
        bool Truncated,
        string? TruncationReason,
        int ReturnedCount,
        int TotalCount,
        bool SymbolSupport,
        bool Ambiguous,
        bool DisplayTruncated,
        string ArtifactState,
        IReadOnlyList<RepositoryItemRow> Entries)
    {
        public string Time => Timestamp.ToLocalTime().ToString("HH:mm:ss");
        public string CountDisplay => TotalCount > 0 ? $"{ReturnedCount}/{TotalCount}" : ReturnedCount.ToString();
        public string StateDisplay => Partial || Truncated || DisplayTruncated ? "Partial" : "Observed";
    }

    private sealed record ArtifactBatchEntryRow(
        string Path,
        string State,
        string Delivery,
        long? SizeBytes,
        long? MaxBytes,
        string? VersionStrength,
        long? ExpiresEpochMs,
        string? BlobId,
        bool ContentRefPresent,
        string? ErrorCode,
        string? Message)
    {
        public string SizeDisplay => SizeBytes is null ? "N/A" : $"{SizeBytes.Value:N0} B";
        public string ExpiryDisplay => ExpiresEpochMs is null
            ? "N/A"
            : DateTimeOffset.FromUnixTimeMilliseconds(ExpiresEpochMs.Value).ToLocalTime().ToString("MM-dd HH:mm");
    }

    private sealed record ArtifactBatchRow(
        DateTimeOffset Timestamp,
        string Workspace,
        string Operation,
        int RequestedCount,
        int CompletedCount,
        bool Partial,
        bool Cancelled,
        bool Truncated,
        string? TruncationReason,
        int ContentRefCount,
        int QuotaErrorCount,
        IReadOnlyList<ArtifactBatchEntryRow> Entries)
    {
        public string Time => Timestamp.ToLocalTime().ToString("HH:mm:ss");
        public string CompletionDisplay => $"{CompletedCount}/{RequestedCount}";
        public string StateDisplay => Cancelled ? "Cancelled" : Partial ? "Partial" : Truncated ? "Truncated" : "Complete";
    }

    private sealed record EvidenceRow(
        DateTimeOffset Timestamp,
        string Workspace,
        string EvidenceId,
        string OperationId,
        string Criterion,
        string VerificationState,
        string OperationState,
        string StorageStatus,
        string SourceBinding,
        string? SourceStateId,
        string? ProjectContextDigest,
        string PolicyHash,
        string CatalogHash,
        string CatalogVersion,
        string? BlockReason)
    {
        public string Time => Timestamp.ToLocalTime().ToString("HH:mm:ss");
        public string DisplayState => VerificationState == "not-applicable" ? "N/A" : VerificationState;
    }

    private sealed record ChangeRow(
        DateTimeOffset Timestamp,
        string Status,
        string Workspace,
        string Operation,
        string Summary,
        string Detail,
        string? Target = null,
        string? VersionContext = null)
    {
        public string Time => Timestamp.ToLocalTime().ToString("HH:mm:ss");
    }

    private sealed record ActivityRow(
        DateTimeOffset Timestamp,
        string Kind,
        string Workspace,
        string Summary,
        string Detail)
    {
        public string Time => Timestamp.ToLocalTime().ToString("HH:mm:ss");
    }

    private void RecordActivity(string text)
    {
        foreach (var rawLine in text.Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries))
        {
            var line = rawLine.Trim();
            if (line.Length == 0) continue;

            var workspace = "Global";
            if (line.StartsWith("[") && line.IndexOf(']') is var close && close > 1)
                workspace = line[1..close];

            TryCaptureEvidenceRow(line, workspace);
            TryCaptureRepositoryRow(line, workspace);
            TryCaptureArtifactBatchRow(line, workspace);

            var lower = line.ToLowerInvariant();
            var kind = lower.Contains("error") || lower.Contains("failed") || lower.Contains("could not")
                ? "Error"
                : lower.Contains("settings") || lower.Contains("connection")
                    ? "Settings"
                    : lower.Contains("runtime") || lower.Contains("tunnel") || workspace != "Global"
                        ? "Runtime"
                        : "System";

            var summary = line.Length <= 140 ? line : line[..137] + "...";
            _activityRows.Add(new ActivityRow(DateTimeOffset.Now, kind, workspace, summary, line));

            if (TryCreateChangeRow(line, workspace, out var change))
                _changeRows.Add(change);
        }

        if (_activityRows.Count > MaxActivityRows)
            _activityRows.RemoveRange(0, _activityRows.Count - MaxActivityRows);
        if (_changeRows.Count > MaxChangeRows)
            _changeRows.RemoveRange(0, _changeRows.Count - MaxChangeRows);
        if (_evidenceRows.Count > MaxEvidenceRows)
            _evidenceRows.RemoveRange(0, _evidenceRows.Count - MaxEvidenceRows);
        if (_repositoryRows.Count > MaxRepositoryRows)
            _repositoryRows.RemoveRange(0, _repositoryRows.Count - MaxRepositoryRows);
        if (_artifactBatchRows.Count > MaxArtifactBatchRows)
            _artifactBatchRows.RemoveRange(0, _artifactBatchRows.Count - MaxArtifactBatchRows);

    }

    private void TryCaptureRepositoryRow(string line, string workspace)
    {
        const string marker = "[RepositoryIntelligenceResult] ";
        var markerIndex = line.IndexOf(marker, StringComparison.Ordinal);
        if (markerIndex < 0) return;

        try
        {
            var json = line[(markerIndex + marker.Length)..];
            var node = JsonNode.Parse(json)?.AsObject();
            if (node is null) return;

            static string Text(JsonObject obj, string key, string fallback = "unknown") =>
                obj[key] is JsonValue value && value.TryGetValue<string>(out var text) ? text : fallback;
            static string? OptionalText(JsonObject obj, string key) =>
                obj[key] is JsonValue value && value.TryGetValue<string>(out var text) ? text : null;
            static int Int(JsonObject obj, string key) =>
                obj[key] is JsonValue value && value.TryGetValue<int>(out var number) ? number : 0;
            static bool Bool(JsonObject obj, string key) =>
                obj[key] is JsonValue value && value.TryGetValue<bool>(out var flag) && flag;
            static string Score(JsonObject obj)
            {
                if (obj["score"] is JsonValue value && value.TryGetValue<double>(out var score))
                    return score.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture);
                return "";
            }

            var queryKind = Text(node, "query_kind", "repository");
            var entries = new List<RepositoryItemRow>();
            if (node["entries"] is JsonArray array)
            {
                foreach (var child in array)
                {
                    if (child is not JsonObject entry) continue;
                    var path = Text(entry, "path", "(unknown)");
                    var name = OptionalText(entry, "name") ?? OptionalText(entry, "language") ?? "";
                    var kind = OptionalText(entry, "kind") ?? (queryKind == "repo_map" ? "file" : "");
                    var detail = queryKind switch
                    {
                        "repo_map" => $"language={Text(entry, "language", "unknown")} | size={Int(entry, "size_bytes"):N0} B | symbols={Int(entry, "symbol_count")} | imports={Int(entry, "import_count")} | relations={Int(entry, "relation_count")} | supported={Bool(entry, "supported_language")}",
                        "symbol_search" => $"line={Int(entry, "line")}",
                        "related_files" => $"direction={Text(entry, "direction", "unknown")}",
                        _ => "Observed metadata"
                    };
                    entries.Add(new RepositoryItemRow(path, name, kind, detail, Score(entry)));
                }
            }

            var total = Int(node, "total_items");
            if (total == 0) total = Int(node, "total_results");
            _repositoryRows.Add(new RepositoryResultRow(
                DateTimeOffset.Now,
                workspace,
                queryKind,
                Text(node, "provider_id", "unknown"),
                Text(node, "provider_version", "unknown"),
                Text(node, "completeness", "unknown"),
                Text(node, "source_state_id", "unknown"),
                Bool(node, "grants_authority"),
                Bool(node, "raw_source_persisted"),
                Bool(node, "partial"),
                Bool(node, "truncated") || Bool(node, "generation_truncated"),
                OptionalText(node, "truncation_reason") ?? OptionalText(node, "generation_truncation_reason"),
                Int(node, "returned_count"),
                total,
                Bool(node, "symbol_support"),
                Bool(node, "ambiguous"),
                Bool(node, "display_truncated"),
                Text(node, "artifact_state", "none"),
                entries));
        }
        catch
        {
            // Repository UI ignores malformed presentation telemetry rather than inventing state.
        }
    }

    private void RefreshRepositoryGrid()
    {
        var visible = _repositoryRows.AsEnumerable().Reverse().ToArray();
        RepositoryResultGrid.ItemsSource = visible;
        RepositoryResultCountText.Text = visible.Length == 0
            ? "0 captured repository-intelligence results | waiting for real repo_map / symbol_search / related_files output"
            : $"{visible.Length} captured repository-intelligence result(s) | max {MaxRepositoryRows}";
        if (visible.Length == 0)
        {
            RepositoryItemGrid.ItemsSource = Array.Empty<RepositoryItemRow>();
            RepositoryProviderText.Text = "No repository-intelligence result captured yet.";
            RepositorySummaryText.Text = "Waiting for real repo_map, symbol_search or related_files output.";
            RepositorySourceText.Text = "Not observed";
        }
    }

    private void RepositoryResultGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (RepositoryResultGrid.SelectedItem is not RepositoryResultRow row)
        {
            RepositoryItemGrid.ItemsSource = Array.Empty<RepositoryItemRow>();
            RepositoryProviderText.Text = "Select a captured repository-intelligence result.";
            RepositorySummaryText.Text = "No synthetic repository state is shown.";
            RepositorySourceText.Text = "Not observed";
            return;
        }

        RepositoryItemGrid.ItemsSource = row.Entries;
        RepositoryProviderText.Text =
            $"{row.ProviderId} {row.ProviderVersion} | completeness={row.Completeness} | grants_authority={row.GrantsAuthority} | raw_source_persisted={row.RawSourcePersisted}";
        var flags = new List<string>();
        if (row.Partial) flags.Add("partial");
        if (row.Truncated) flags.Add($"truncated:{row.TruncationReason ?? "unknown"}");
        if (row.DisplayTruncated) flags.Add("display-bounded");
        if (row.Ambiguous) flags.Add("ambiguous");
        var state = flags.Count == 0 ? "observed" : string.Join(", ", flags);
        RepositorySummaryText.Text =
            $"{row.QueryKind}: {row.ReturnedCount}/{row.TotalCount} returned | {state} | {row.Entries.Count} metadata row(s) displayed | symbol_support={row.SymbolSupport} | artifact_state={row.ArtifactState}. Provider completeness is descriptive, not exhaustive truth.";
        RepositorySourceText.Text = $"source_state_id={row.SourceStateId}";
    }

    private void RefreshBackendGrid()
    {
        var priorKey = (BackendGrid.SelectedItem as BackendStatusRow)?.Key;
        var rows = new List<BackendStatusRow>();
        var unavailable = new List<string>();
        foreach (var workspace in WorkspaceKeys)
        {
            if (!_runtimes.TryGetValue(workspace, out var runtime) || runtime.State.Status != LocalMcpRuntimeStatus.Running)
                continue;
            try
            {
                var metadata = runtime.PresentationExecutionBackendMetadata();
                rows.Add(new BackendStatusRow(
                    workspace,
                    JsonText(metadata, "backend_id", "unknown"),
                    JsonText(metadata, "backend_version", "unknown"),
                    JsonBool(metadata, "backend_available"),
                    JsonText(metadata, "backend_state", "unknown"),
                    JsonBool(metadata, "backend_isolation_active"),
                    JsonBool(metadata, "docker_selected"),
                    JsonText(metadata, "docker_availability_state", "unknown"),
                    JsonText(metadata, "backend_workspace_mode", "unknown"),
                    JsonText(metadata, "backend_environment_mode", "unknown"),
                    JsonText(metadata, "backend_network_mode", "unknown"),
                    JsonText(metadata, "backend_resource_mode", "unknown"),
                    JsonStringList(metadata, "backend_capabilities"),
                    JsonText(metadata, "image_digest", "-"),
                    JsonText(metadata, "network_policy", JsonText(metadata, "backend_network_mode", "unknown")),
                    JsonText(metadata, "resource_policy", JsonText(metadata, "backend_resource_mode", "unknown"))));
            }
            catch (Exception ex)
            {
                unavailable.Add($"{workspace}: {ex.Message}");
            }
        }

        _backendRows.Clear();
        _backendRows.AddRange(rows);
        BackendGrid.ItemsSource = null;
        BackendGrid.ItemsSource = _backendRows;
        var selected = priorKey is null ? _backendRows.FirstOrDefault() : _backendRows.FirstOrDefault(row => row.Key == priorKey) ?? _backendRows.FirstOrDefault();
        if (selected is not null)
        {
            BackendGrid.SelectedItem = selected;
            UpdateBackendSelection(selected);
        }
        else
        {
            BackendDetailText.Text = "No connected workspace backend is available to observe.";
        }
        BackendSummaryText.Text = _backendRows.Count == 0
            ? "No connected backend observed."
            : $"{_backendRows.Count} connected workspace backend(s) observed. Read-only presentation; no backend selector is exposed.";
        BackendStatusText.Text = unavailable.Count == 0
            ? "presentation_grants_authority=false | Docker not selected means not probed, not available."
            : $"presentation_grants_authority=false | unavailable observation: {string.Join("; ", unavailable)}";
    }

    private void UpdateBackendSelection(BackendStatusRow row)
    {
        BackendDetailText.Text =
            $"Workspace {row.Workspace} | {row.BackendDisplay} | state={row.State} | available={row.Available}\n" +
            $"isolation={row.IsolationDisplay} | workspace={row.WorkspaceMode} | environment={row.EnvironmentMode}\n" +
            $"network={row.NetworkMode} (policy={row.NetworkPolicy}) | resource={row.ResourceMode} (policy={row.ResourcePolicy})\n" +
            $"Docker={row.DockerDisplay} | image_digest={row.ImageDigest}\n" +
            $"capabilities={row.Capabilities}\nPresentation is read-only and grants no execution authority.";
    }

    private void BackendGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (BackendGrid.SelectedItem is BackendStatusRow row) UpdateBackendSelection(row);
    }

    private void BackendRefresh_Click(object sender, RoutedEventArgs e) => RefreshBackendGrid();

    private async Task RefreshTerminalAsync(bool readSelectedOutput)
    {
        if (_terminalRefreshRunning) return;
        _terminalRefreshRunning = true;
        try
        {
            var priorSelectionKey = (TerminalSessionGrid.SelectedItem as TerminalSessionRow)?.Key;
            var rows = new List<TerminalSessionRow>();
            var unavailable = new List<string>();

            foreach (var workspace in WorkspaceKeys)
            {
                if (!_runtimes.TryGetValue(workspace, out var runtime) || runtime.State.Status != LocalMcpRuntimeStatus.Running)
                    continue;

                try
                {
                    var policy = runtime.PresentationPolicyMetadata();
                    var result = await runtime.CallPresentationPtyToolAsync("pty_list", new JsonObject());
                    var backendId = JsonText(result, "backend_id", "unknown");
                    var backendVersion = JsonText(result, "backend_version", "unknown");
                    var capabilities = JsonStringList(result, "backend_capabilities");
                    if (result["sessions"] is not JsonArray sessions) continue;

                    foreach (var node in sessions)
                    {
                        if (node is not JsonObject session) continue;
                        var sessionId = JsonText(session, "session_id", "");
                        if (sessionId.Length == 0) continue;
                        rows.Add(new TerminalSessionRow(
                            workspace,
                            sessionId,
                            JsonNullableInt(session, "pid"),
                            JsonText(session, "state", "unknown"),
                            JsonLong(session, "last_activity_epoch_ms"),
                            JsonText(session, "earliest_cursor", ""),
                            JsonText(session, "end_cursor", ""),
                            JsonNullableInt(session, "exit_code"),
                            JsonInt(session, "spill_ref_count"),
                            JsonBool(session, "actual_pty"),
                            JsonBool(session, "restart_resume_supported"),
                            JsonBool(session, "grants_authority"),
                            backendId,
                            backendVersion,
                            capabilities,
                            JsonText(policy, "profile", "unknown"),
                            JsonLong(policy, "generation"),
                            JsonText(policy, "hash", "unknown")));
                    }
                }
                catch (Exception ex)
                {
                    unavailable.Add($"{workspace}: {ex.Message}");
                }
            }

            _terminalRows.Clear();
            _terminalRows.AddRange(rows.OrderBy(row => row.Workspace, StringComparer.Ordinal).ThenBy(row => row.SessionId, StringComparer.Ordinal));
            TerminalSessionGrid.ItemsSource = null;
            TerminalSessionGrid.ItemsSource = _terminalRows;

            var selected = priorSelectionKey is null
                ? _terminalRows.FirstOrDefault()
                : _terminalRows.FirstOrDefault(row => row.Key == priorSelectionKey) ?? _terminalRows.FirstOrDefault();
            TerminalSessionGrid.SelectedItem = selected;

            if (selected is null)
            {
                TerminalSelectionText.Text = "Select a PTY session";
                TerminalBackendText.Text = "No live PTY session observed.";
                TerminalPolicyText.Text = "No connected workspace session selected.";
                SetTerminalControlsEnabled(false);
            }
            else
            {
                if (!string.Equals(priorSelectionKey, selected.Key, StringComparison.Ordinal))
                {
                    _terminalReadCursors.Remove(selected.Key);
                    TerminalOutputText.Clear();
                }
                UpdateTerminalSelection(selected);
                if (readSelectedOutput)
                    await ReadTerminalOutputAsync(selected);
            }

            TerminalStatusText.Text = unavailable.Count == 0
                ? $"{_terminalRows.Count} observed PTY session(s) | bounded read={TerminalReadWindowBytes / 1024} KiB | restart resume unsupported"
                : $"{_terminalRows.Count} observed PTY session(s) | unavailable: {string.Join("; ", unavailable)}";
        }
        finally
        {
            _terminalRefreshRunning = false;
        }
    }

    private async Task ReadTerminalOutputAsync(TerminalSessionRow row)
    {
        if (!_runtimes.TryGetValue(row.Workspace, out var runtime) || runtime.State.Status != LocalMcpRuntimeStatus.Running)
            return;

        try
        {
            var cursor = _terminalReadCursors.TryGetValue(row.Key, out var saved) ? saved : row.EarliestCursor;
            var result = await runtime.CallPresentationPtyToolAsync("pty_read", new JsonObject
            {
                ["session_id"] = row.SessionId,
                ["cursor"] = cursor,
                ["max_bytes"] = TerminalReadWindowBytes,
            });

            if (JsonBool(result, "cursor_evicted"))
                TerminalOutputText.Text = "[Older PTY output was evicted from the bounded runtime buffer.]\r\n";

            var text = JsonText(result, "text", "");
            if (text.Length > 0)
                AppendTerminalOutput(text);

            var nextCursor = JsonText(result, "next_cursor", cursor);
            if (nextCursor.Length > 0)
                _terminalReadCursors[row.Key] = nextCursor;
        }
        catch (Exception ex)
        {
            TerminalStatusText.Text = $"PTY output unavailable for {row.Workspace}: {ex.Message}";
        }
    }

    private void AppendTerminalOutput(string text)
    {
        var combined = TerminalOutputText.Text + text;
        if (combined.Length > MaxTerminalOutputCharacters)
            combined = combined[^MaxTerminalOutputCharacters..];
        ApplyTextPreservingLiveTail(TerminalOutputText, combined);
    }

    private static void ApplyTextPreservingLiveTail(System.Windows.Controls.TextBox textBox, string text)
    {
        var priorOffset = textBox.VerticalOffset;
        var scrollableHeight = Math.Max(0d, textBox.ExtentHeight - textBox.ViewportHeight);
        var wasFollowingTail = scrollableHeight <= 1d || priorOffset >= scrollableHeight - 1d;

        textBox.Text = text;
        if (wasFollowingTail)
            textBox.ScrollToEnd();
        else
            textBox.ScrollToVerticalOffset(priorOffset);
    }

    private void UpdateTerminalSelection(TerminalSessionRow row)
    {
        TerminalSelectionText.Text = $"{row.Workspace}: {row.SessionId} | state={row.State} | exit={row.ExitCode?.ToString() ?? "-"}";
        TerminalBackendText.Text = $"{row.BackendId} {row.BackendVersion} | capabilities={row.BackendCapabilities} | actual_pty={row.ActualPty} | restart_resume_supported={row.RestartResumeSupported} | grants_authority={row.GrantsAuthority}";
        var hash = row.PolicyHash.Length > 16 ? row.PolicyHash[..16] + "..." : row.PolicyHash;
        TerminalPolicyText.Text = $"profile={row.PolicyProfile} | generation={row.PolicyGeneration} | hash={hash} | presentation_grants_authority=false";
        SetTerminalControlsEnabled(row.IsControllable);
    }

    private void SetTerminalControlsEnabled(bool enabled)
    {
        TerminalCtrlCButton.IsEnabled = enabled;
        TerminalStopButton.IsEnabled = enabled;
        TerminalResizeButton.IsEnabled = enabled;
    }

    private async void TerminalSessionGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_terminalRefreshRunning || TerminalSessionGrid.SelectedItem is not TerminalSessionRow row) return;
        _terminalReadCursors.Remove(row.Key);
        TerminalOutputText.Clear();
        UpdateTerminalSelection(row);
        await ReadTerminalOutputAsync(row);
    }

    private async void TerminalCtrlC_Click(object sender, RoutedEventArgs e)
    {
        if (TerminalSessionGrid.SelectedItem is not TerminalSessionRow row) return;
        await ExecuteTerminalControlAsync(row, "pty_signal", new JsonObject
        {
            ["session_id"] = row.SessionId,
            ["signal"] = "ctrl_c",
        }, "Ctrl+C sent");
    }

    private async void TerminalStop_Click(object sender, RoutedEventArgs e)
    {
        if (TerminalSessionGrid.SelectedItem is not TerminalSessionRow row) return;
        await ExecuteTerminalControlAsync(row, "pty_stop", new JsonObject { ["session_id"] = row.SessionId }, "PTY session stopped");
    }

    private async void TerminalResize_Click(object sender, RoutedEventArgs e)
    {
        if (TerminalSessionGrid.SelectedItem is not TerminalSessionRow row) return;
        if (!int.TryParse(TerminalColumnsBox.Text.Trim(), out var columns) || columns is < 1 or > 500 ||
            !int.TryParse(TerminalRowsBox.Text.Trim(), out var rows) || rows is < 1 or > 300)
        {
            TerminalStatusText.Text = "Resize requires columns 1..500 and rows 1..300.";
            return;
        }

        await ExecuteTerminalControlAsync(row, "pty_resize", new JsonObject
        {
            ["session_id"] = row.SessionId,
            ["columns"] = columns,
            ["rows"] = rows,
        }, $"PTY resized to {columns}x{rows}");
    }

    private async Task ExecuteTerminalControlAsync(TerminalSessionRow row, string toolName, JsonObject arguments, string successMessage)
    {
        if (!_runtimes.TryGetValue(row.Workspace, out var runtime) || runtime.State.Status != LocalMcpRuntimeStatus.Running)
        {
            TerminalStatusText.Text = $"Workspace {row.Workspace} is not connected.";
            return;
        }

        try
        {
            await runtime.CallPresentationPtyToolAsync(toolName, arguments);
            TerminalStatusText.Text = $"{successMessage} | {row.Workspace}: {row.SessionId}";
            await RefreshTerminalAsync(readSelectedOutput: false);
        }
        catch (Exception ex)
        {
            TerminalStatusText.Text = $"PTY control blocked/unavailable: {ex.Message}";
        }
    }

    private async Task RefreshRecoveryAsync()
    {
        if (_recoveryRefreshRunning) return;
        _recoveryRefreshRunning = true;
        try
        {
            var priorQuarantineKey = (RecoveryQuarantineGrid.SelectedItem as RecoveryQuarantineRow)?.Key;
            var priorCheckpointKey = (RecoveryCheckpointGrid.SelectedItem as RecoveryCheckpointRow)?.Key;
            var quarantineRows = new List<RecoveryQuarantineRow>();
            var checkpointRows = new List<RecoveryCheckpointRow>();
            var unavailable = new List<string>();
            var connected = new List<string>();

            foreach (var workspace in WorkspaceKeys)
            {
                if (!_runtimes.TryGetValue(workspace, out var runtime) || runtime.State.Status != LocalMcpRuntimeStatus.Running)
                    continue;

                try
                {
                    _ = runtime.PresentationPolicyMetadata();
                    connected.Add(workspace);
                    var quarantine = await runtime.CallPresentationRecoveryToolAsync("quarantine_list", new JsonObject { ["max_items"] = 200 });
                    if (quarantine["items"] is JsonArray quarantineItems)
                    {
                        foreach (var node in quarantineItems)
                        {
                            if (node is not JsonObject item) continue;
                            var quarantineRef = JsonText(item, "quarantine_ref", "");
                            if (quarantineRef.Length == 0) continue;
                            quarantineRows.Add(new RecoveryQuarantineRow(
                                workspace,
                                quarantineRef,
                                JsonText(item, "original_relative_path", "(unknown)"),
                                JsonText(item, "state", "unknown"),
                                JsonBool(item, "is_tree"),
                                JsonBool(item, "expired"),
                                JsonLong(item, "created_epoch_ms"),
                                JsonLong(item, "expires_epoch_ms"),
                                JsonInt(item, "entry_count"),
                                JsonLong(item, "total_bytes"),
                                JsonText(item, "last_restore_target", "") is var last && last.Length > 0 ? last : null,
                                JsonText(item, "recovery_ref", "") is var recovery && recovery.Length > 0 ? recovery : null));
                        }
                    }

                    var checkpoints = await runtime.CallPresentationRecoveryToolAsync("checkpoint_list", new JsonObject { ["max_items"] = 200 });
                    if (checkpoints["items"] is JsonArray checkpointItems)
                    {
                        foreach (var node in checkpointItems)
                        {
                            if (node is not JsonObject item) continue;
                            var checkpointRef = JsonText(item, "checkpoint_ref", "");
                            if (checkpointRef.Length == 0) continue;
                            var head = JsonText(item, "head_oid", "");
                            checkpointRows.Add(new RecoveryCheckpointRow(
                                workspace,
                                checkpointRef,
                                JsonText(item, "repository_relative_path", "."),
                                head.Length == 0 ? null : head,
                                JsonText(item, "source_state_id", "unknown"),
                                JsonBool(item, "expired"),
                                JsonLong(item, "created_epoch_ms"),
                                JsonLong(item, "expires_epoch_ms"),
                                JsonInt(item, "entry_count"),
                                JsonLong(item, "total_bytes"),
                                JsonInt(item, "staged_count"),
                                JsonInt(item, "unstaged_count"),
                                JsonInt(item, "untracked_count"),
                                JsonInt(item, "ignored_count"),
                                JsonInt(item, "excluded_count")));
                        }
                    }
                }
                catch (Exception ex)
                {
                    unavailable.Add($"{workspace}: {ex.Message}");
                }
            }

            _recoveryQuarantineRows.Clear();
            _recoveryQuarantineRows.AddRange(quarantineRows.OrderBy(row => row.Workspace, StringComparer.Ordinal).ThenByDescending(row => row.CreatedEpochMs));
            _recoveryCheckpointRows.Clear();
            _recoveryCheckpointRows.AddRange(checkpointRows.OrderBy(row => row.Workspace, StringComparer.Ordinal).ThenByDescending(row => row.CreatedEpochMs));
            _plannedCheckpointKeys.RemoveWhere(key => !_recoveryCheckpointRows.Any(row => row.Key == key));

            RecoveryQuarantineGrid.ItemsSource = null;
            RecoveryQuarantineGrid.ItemsSource = _recoveryQuarantineRows;
            RecoveryCheckpointGrid.ItemsSource = null;
            RecoveryCheckpointGrid.ItemsSource = _recoveryCheckpointRows;

            var quarantineSelection = priorQuarantineKey is null ? null : _recoveryQuarantineRows.FirstOrDefault(row => row.Key == priorQuarantineKey);
            var checkpointSelection = priorCheckpointKey is null ? null : _recoveryCheckpointRows.FirstOrDefault(row => row.Key == priorCheckpointKey);
            if (quarantineSelection is not null)
                RecoveryQuarantineGrid.SelectedItem = quarantineSelection;
            else if (checkpointSelection is not null)
                RecoveryCheckpointGrid.SelectedItem = checkpointSelection;
            else if (_recoveryQuarantineRows.Count > 0)
                RecoveryQuarantineGrid.SelectedItem = _recoveryQuarantineRows[0];
            else if (_recoveryCheckpointRows.Count > 0)
                RecoveryCheckpointGrid.SelectedItem = _recoveryCheckpointRows[0];

            RecoveryWorkspaceText.Text = connected.Count == 0
                ? "No connected workspace exposes Recovery state."
                : $"Connected workspace(s): {string.Join(", ", connected)} | root paths are shown in the selected detail before mutation.";
            RecoveryPolicyText.Text = "Recovery presentation grants no authority. Core policy, expected-version/source-state checks and rollback rules remain authoritative.";
            var recoverySummary = unavailable.Count == 0
                ? $"{_recoveryQuarantineRows.Count} quarantine item(s) | {_recoveryCheckpointRows.Count} checkpoint(s) | partial recovery is never hidden"
                : $"{_recoveryQuarantineRows.Count} quarantine item(s) | {_recoveryCheckpointRows.Count} checkpoint(s) | unavailable: {string.Join("; ", unavailable)}";
            RecoveryStatusText.Text = string.IsNullOrWhiteSpace(_recoveryPersistentNotice)
                ? recoverySummary
                : $"{_recoveryPersistentNotice} | {recoverySummary}";

            if (RecoveryQuarantineGrid.SelectedItem is RecoveryQuarantineRow selectedQuarantine)
                await LoadRecoveryQuarantineDetailAsync(selectedQuarantine);
            else if (RecoveryCheckpointGrid.SelectedItem is RecoveryCheckpointRow selectedCheckpoint)
                await LoadRecoveryCheckpointDetailAsync(selectedCheckpoint);
            else
                ResetRecoveryDetail();
        }
        finally
        {
            _recoveryRefreshRunning = false;
        }
    }

    private async Task LoadRecoveryQuarantineDetailAsync(RecoveryQuarantineRow row)
    {
        SetRecoveryButtons(row.CanRestore, false, false);
        RecoveryDetailTitle.Text = $"Quarantine | {row.Workspace}: {row.OriginalPath}";
        if (!_runtimes.TryGetValue(row.Workspace, out var runtime) || runtime.State.Status != LocalMcpRuntimeStatus.Running)
        {
            RecoveryDetailText.Text = $"Root: {PathBox(row.Workspace).Text.Trim()} | workspace is not connected.";
            return;
        }
        try
        {
            var detail = await runtime.CallPresentationRecoveryToolAsync("quarantine_get", new JsonObject { ["quarantine_ref"] = row.QuarantineRef });
            RecoveryDetailText.Text =
                $"Root: {PathBox(row.Workspace).Text.Trim()}\nState: {JsonText(detail, "state", "unknown")} | tree={JsonBool(detail, "is_tree")} | expired={JsonBool(detail, "expired")}\n" +
                $"Entries: {JsonInt(detail, "entry_count")} | bytes: {JsonLong(detail, "total_bytes"):N0} | expires: {row.ExpiryDisplay}\n" +
                $"Original path: {JsonText(detail, "original_relative_path", row.OriginalPath)} | last restore target: {JsonText(detail, "last_restore_target", "-")}\n" +
                $"Recovery state is core-authenticated; restore uses the original path only and refuses silent replacement.";
        }
        catch (Exception ex)
        {
            RecoveryDetailText.Text = $"Quarantine detail unavailable. Root: {PathBox(row.Workspace).Text.Trim()} | {ex.Message}";
            SetRecoveryButtons(false, false, false);
        }
    }

    private async Task LoadRecoveryCheckpointDetailAsync(RecoveryCheckpointRow row)
    {
        var planned = _plannedCheckpointKeys.Contains(row.Key);
        SetRecoveryButtons(false, row.CanPlan, row.CanPlan && planned);
        RecoveryDetailTitle.Text = $"Checkpoint | {row.Workspace}: {row.RepositoryPath}";
        if (!_runtimes.TryGetValue(row.Workspace, out var runtime) || runtime.State.Status != LocalMcpRuntimeStatus.Running)
        {
            RecoveryDetailText.Text = $"Root: {PathBox(row.Workspace).Text.Trim()} | workspace is not connected.";
            return;
        }
        try
        {
            var detail = await runtime.CallPresentationRecoveryToolAsync("checkpoint_get", new JsonObject { ["checkpoint_ref"] = row.CheckpointRef });
            var preview = new List<string>();
            if (detail["entries"] is JsonArray entries)
            {
                foreach (var node in entries.Take(12))
                {
                    if (node is not JsonObject entry) continue;
                    preview.Add($"{JsonText(entry, "relative_path", "?")} [staged={JsonBool(entry, "staged")}, unstaged={JsonBool(entry, "unstaged")}, untracked={JsonBool(entry, "untracked")}, excluded={JsonText(entry, "worktree_excluded_reason", "-")}] ");
                }
            }
            var head = JsonText(detail, "head_oid", "-");
            RecoveryDetailText.Text =
                $"Root: {PathBox(row.Workspace).Text.Trim()} | repository: {row.RepositoryPath}\nExpired: {row.Expired} | entries={row.EntryCount} | excluded={row.ExcludedCount} | bytes={row.TotalBytes:N0}\n" +
                $"Git: staged={row.StagedCount}, unstaged={row.UnstagedCount}, untracked={row.UntrackedCount}, ignored={row.IgnoredCount} | head={head}\n" +
                $"Source state: {row.SourceStateId} | restore plan ready={planned}\n" +
                (preview.Count == 0 ? "No captured entry metadata." : string.Join("\n", preview));
        }
        catch (Exception ex)
        {
            RecoveryDetailText.Text = $"Checkpoint detail unavailable. Root: {PathBox(row.Workspace).Text.Trim()} | {ex.Message}";
            SetRecoveryButtons(false, false, false);
        }
    }

    private void ResetRecoveryDetail()
    {
        RecoveryDetailTitle.Text = "Select a quarantine item or checkpoint";
        RecoveryDetailText.Text = "No synthetic recovery state is shown.";
        SetRecoveryButtons(false, false, false);
    }

    private void SetRecoveryButtons(bool quarantineRestore, bool checkpointPlan, bool checkpointRestore)
    {
        RecoveryRestoreQuarantineButton.IsEnabled = quarantineRestore;
        RecoveryPlanCheckpointButton.IsEnabled = checkpointPlan;
        RecoveryRestoreCheckpointButton.IsEnabled = checkpointRestore;
    }

    private async void RecoveryQuarantineGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_recoveryRefreshRunning || RecoveryQuarantineGrid.SelectedItem is not RecoveryQuarantineRow row) return;
        RecoveryCheckpointGrid.SelectedItem = null;
        await LoadRecoveryQuarantineDetailAsync(row);
    }

    private async void RecoveryCheckpointGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_recoveryRefreshRunning || RecoveryCheckpointGrid.SelectedItem is not RecoveryCheckpointRow row) return;
        RecoveryQuarantineGrid.SelectedItem = null;
        await LoadRecoveryCheckpointDetailAsync(row);
    }

    private async void RecoveryRefresh_Click(object sender, RoutedEventArgs e) => await RefreshRecoveryAsync();

    private async void RecoveryRestoreQuarantine_Click(object sender, RoutedEventArgs e)
    {
        if (RecoveryQuarantineGrid.SelectedItem is not RecoveryQuarantineRow row || !row.CanRestore) return;
        var root = PathBox(row.Workspace).Text.Trim();
        var answer = System.Windows.MessageBox.Show(
            $"Restore quarantine item to its original path?\n\nWorkspace root: {root}\nTarget: {row.OriginalPath}\n\nExisting targets are not replaced by this UI; core policy and Mutation Guard revalidate before write.",
            "Restore quarantined item",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (answer != MessageBoxResult.Yes) return;
        if (!_runtimes.TryGetValue(row.Workspace, out var runtime) || runtime.State.Status != LocalMcpRuntimeStatus.Running) return;
        try
        {
            var result = await runtime.CallPresentationRecoveryToolAsync("quarantine_restore", new JsonObject { ["quarantine_ref"] = row.QuarantineRef });
            var state = JsonText(result, "state", "unknown");
            RecoveryStatusText.Text = state switch
            {
                "restored" => $"Quarantine restore completed: {row.Workspace}:{row.OriginalPath}",
                "rolled_back" => $"Quarantine restore failed and rollback completed: {row.Workspace}:{row.OriginalPath}",
                "partial_recovery_required" => $"HIGH SEVERITY: quarantine restore requires partial recovery: {row.Workspace}:{row.OriginalPath}",
                _ => $"Quarantine restore returned state={state}: {row.Workspace}:{row.OriginalPath}",
            };
            _recoveryPersistentNotice = state == "partial_recovery_required" ? RecoveryStatusText.Text : "";
        }
        catch (Exception ex)
        {
            RecoveryStatusText.Text = $"Quarantine restore blocked/failed; state may be unchanged. {ex.Message}";
        }
        await RefreshRecoveryAsync();
    }

    private async void RecoveryPlanCheckpoint_Click(object sender, RoutedEventArgs e)
    {
        if (RecoveryCheckpointGrid.SelectedItem is not RecoveryCheckpointRow row || !row.CanPlan) return;
        if (!_runtimes.TryGetValue(row.Workspace, out var runtime) || runtime.State.Status != LocalMcpRuntimeStatus.Running) return;
        try
        {
            var result = await runtime.CallPresentationRecoveryToolAsync("checkpoint_restore", new JsonObject
            {
                ["checkpoint_ref"] = row.CheckpointRef,
                ["history_mode"] = "preserve",
                ["dry_run"] = true,
            });
            var state = JsonText(result, "state", "unknown");
            if (string.Equals(state, "planned", StringComparison.OrdinalIgnoreCase))
                _plannedCheckpointKeys.Add(row.Key);
            RecoveryStatusText.Text = $"Checkpoint restore plan state={state} | workspace={row.Workspace} | paths={JsonInt(result, "path_count")} | skipped={JsonInt(result, "skipped_count")}";
            await LoadRecoveryCheckpointDetailAsync(row);
        }
        catch (Exception ex)
        {
            _plannedCheckpointKeys.Remove(row.Key);
            RecoveryStatusText.Text = $"Checkpoint restore plan blocked/failed; no restore was started. {ex.Message}";
            await LoadRecoveryCheckpointDetailAsync(row);
        }
    }

    private async void RecoveryRestoreCheckpoint_Click(object sender, RoutedEventArgs e)
    {
        if (RecoveryCheckpointGrid.SelectedItem is not RecoveryCheckpointRow row || !_plannedCheckpointKeys.Contains(row.Key)) return;
        var root = PathBox(row.Workspace).Text.Trim();
        var answer = System.Windows.MessageBox.Show(
            $"Apply the checkpoint restore plan?\n\nWorkspace root: {root}\nRepository: {row.RepositoryPath}\nHistory mode: preserve\n\nCore source-state validation and rollback checkpoint protection run again before mutation.",
            "Restore checkpoint",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (answer != MessageBoxResult.Yes) return;
        if (!_runtimes.TryGetValue(row.Workspace, out var runtime) || runtime.State.Status != LocalMcpRuntimeStatus.Running) return;
        try
        {
            var result = await runtime.CallPresentationRecoveryToolAsync("checkpoint_restore", new JsonObject
            {
                ["checkpoint_ref"] = row.CheckpointRef,
                ["history_mode"] = "preserve",
                ["dry_run"] = false,
            });
            _plannedCheckpointKeys.Remove(row.Key);
            var state = JsonText(result, "state", "unknown");
            RecoveryStatusText.Text = state switch
            {
                "restored" => $"Checkpoint restored: {row.Workspace}:{row.RepositoryPath}",
                "rolled_back" => $"Checkpoint restore failed and rollback completed: {row.Workspace}:{row.RepositoryPath}",
                "partial_recovery_required" => $"HIGH SEVERITY: checkpoint restore requires partial recovery; rollback checkpoint retained.",
                _ => $"Checkpoint restore returned state={state}: {row.Workspace}:{row.RepositoryPath}",
            };
            _recoveryPersistentNotice = state == "partial_recovery_required" ? RecoveryStatusText.Text : "";
        }
        catch (Exception ex)
        {
            RecoveryStatusText.Text = $"Checkpoint restore blocked/failed; inspect current recovery state before retry. {ex.Message}";
        }
        await RefreshRecoveryAsync();
    }

    private static string JsonText(JsonObject obj, string key, string fallback) =>
        obj[key] is JsonValue value && value.TryGetValue<string>(out var text) ? text : fallback;

    private static int JsonInt(JsonObject obj, string key)
    {
        if (obj[key] is not JsonValue value) return 0;
        if (value.TryGetValue<int>(out var number)) return number;
        return value.TryGetValue<long>(out var wide) && wide is >= int.MinValue and <= int.MaxValue ? (int)wide : 0;
    }

    private static int? JsonNullableInt(JsonObject obj, string key)
    {
        if (obj[key] is not JsonValue value) return null;
        if (value.TryGetValue<int>(out var number)) return number;
        return value.TryGetValue<long>(out var wide) && wide is >= int.MinValue and <= int.MaxValue ? (int)wide : null;
    }

    private static long JsonLong(JsonObject obj, string key)
    {
        if (obj[key] is not JsonValue value) return 0;
        if (value.TryGetValue<long>(out var number)) return number;
        return value.TryGetValue<int>(out var narrow) ? narrow : 0;
    }

    private static bool JsonBool(JsonObject obj, string key) =>
        obj[key] is JsonValue value && value.TryGetValue<bool>(out var flag) && flag;

    private static string JsonStringList(JsonObject obj, string key)
    {
        if (obj[key] is not JsonArray array) return "none";
        var values = array.OfType<JsonValue>()
            .Select(value => value.TryGetValue<string>(out var text) ? text : null)
            .Where(text => !string.IsNullOrWhiteSpace(text));
        return string.Join(",", values!);
    }

    private void TryCaptureArtifactBatchRow(string line, string workspace)
    {
        const string marker = "[ArtifactBatchResult] ";
        var markerIndex = line.IndexOf(marker, StringComparison.Ordinal);
        if (markerIndex < 0) return;

        try
        {
            var json = line[(markerIndex + marker.Length)..];
            var node = JsonNode.Parse(json)?.AsObject();
            if (node is null) return;

            static string Text(JsonObject obj, string key, string fallback = "unknown") =>
                obj[key] is JsonValue value && value.TryGetValue<string>(out var text) ? text : fallback;
            static string? OptionalText(JsonObject obj, string key) =>
                obj[key] is JsonValue value && value.TryGetValue<string>(out var text) ? text : null;
            static int Int(JsonObject obj, string key) =>
                obj[key] is JsonValue value && value.TryGetValue<int>(out var number) ? number : 0;
            static long? OptionalLong(JsonObject obj, string key) =>
                obj[key] is JsonValue value && value.TryGetValue<long>(out var number) ? number : null;
            static bool Bool(JsonObject obj, string key) =>
                obj[key] is JsonValue value && value.TryGetValue<bool>(out var flag) && flag;

            var entries = new List<ArtifactBatchEntryRow>();
            if (node["entries"] is JsonArray array)
            {
                foreach (var child in array)
                {
                    if (child is not JsonObject entry) continue;
                    entries.Add(new ArtifactBatchEntryRow(
                        Text(entry, "path", "(unknown)"),
                        Text(entry, "state", "unknown"),
                        Text(entry, "delivery", "none"),
                        OptionalLong(entry, "size_bytes"),
                        OptionalLong(entry, "max_bytes"),
                        OptionalText(entry, "version_strength"),
                        OptionalLong(entry, "expires_epoch_ms"),
                        OptionalText(entry, "blob_id"),
                        Bool(entry, "content_ref_present"),
                        OptionalText(entry, "error_code"),
                        OptionalText(entry, "message")));
                }
            }

            _artifactBatchRows.Add(new ArtifactBatchRow(
                DateTimeOffset.Now,
                workspace,
                Text(node, "operation", "batch"),
                Int(node, "requested_count"),
                Int(node, "completed_count"),
                Bool(node, "partial"),
                Bool(node, "cancelled"),
                Bool(node, "truncated"),
                OptionalText(node, "truncation_reason"),
                Int(node, "content_ref_count"),
                Int(node, "quota_error_count"),
                entries));
        }
        catch
        {
            // Artifact/Batch UI ignores malformed presentation telemetry rather than inventing state.
        }
    }

    private void RefreshArtifactBatchGrid()
    {
        var visible = _artifactBatchRows.AsEnumerable().Reverse().ToArray();
        ArtifactBatchGrid.ItemsSource = visible;
        ArtifactBatchCountText.Text = visible.Length == 0
            ? "0 captured batch results | waiting for real batch_read / batch_stat results"
            : $"{visible.Length} captured batch result(s) | max {MaxArtifactBatchRows}";
        if (visible.Length == 0)
        {
            ArtifactEntryGrid.ItemsSource = Array.Empty<ArtifactBatchEntryRow>();
            ArtifactBatchSummaryText.Text = "No batch result captured yet.";
            ArtifactQuotaSummaryText.Text = "Quota usage remaining is not emitted by batch results.";
        }
    }

    private void ArtifactBatchGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ArtifactBatchGrid.SelectedItem is not ArtifactBatchRow row)
        {
            ArtifactEntryGrid.ItemsSource = Array.Empty<ArtifactBatchEntryRow>();
            ArtifactBatchSummaryText.Text = "Select a captured batch result.";
            ArtifactQuotaSummaryText.Text = "Quota usage remaining is not emitted by batch results.";
            ArtifactEntryStatus.Status = PresentationStatus.Unavailable;
            ArtifactEntryDetailText.Text = "Select a captured batch entry.";
            return;
        }

        ArtifactEntryGrid.ItemsSource = row.Entries;
        var flags = new List<string>();
        if (row.Partial) flags.Add("partial");
        if (row.Cancelled) flags.Add("cancelled");
        if (row.Truncated) flags.Add($"truncated:{row.TruncationReason ?? "unknown"}");
        var suffix = flags.Count == 0 ? "complete" : string.Join(", ", flags);
        ArtifactBatchSummaryText.Text =
            $"{row.Operation}: {row.CompletedCount}/{row.RequestedCount} completed | {suffix} | {row.Entries.Count} emitted entries.";
        ArtifactQuotaSummaryText.Text =
            $"{row.ContentRefCount} ContentRef delivery item(s); {row.QuotaErrorCount} observed artifact quota error(s). " +
            "Remaining quota is not emitted by the batch result.";
    }

    private void ArtifactEntryGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ArtifactEntryGrid.SelectedItem is not ArtifactBatchEntryRow row)
        {
            ArtifactEntryStatus.Status = PresentationStatus.Unavailable;
            ArtifactEntryDetailText.Text = "Select a captured batch entry.";
            return;
        }

        var expired = row.ExpiresEpochMs is long expiry && expiry <= DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        ArtifactEntryStatus.Status = expired
            ? PresentationStatus.Expired
            : row.ErrorCode == "artifact_quota"
                ? PresentationStatus.Blocked
                : row.State == "ok"
                    ? PresentationStatus.Passed
                    : row.State == "too_large"
                        ? PresentationStatus.Warning
                        : PresentationStatus.Failed;

        var contentRef = row.ContentRefPresent ? "Present (opaque token redacted)" : "Not present";
        ArtifactEntryDetailText.Text =
            $"Path: {row.Path}\nState: {row.State}\nDelivery: {row.Delivery}\nSize: {row.SizeDisplay}\n" +
            $"Max inline bytes: {(row.MaxBytes is null ? "N/A" : $"{row.MaxBytes.Value:N0} B")}\n" +
            $"Version strength: {row.VersionStrength ?? "N/A"}\nContentRef: {contentRef}\n" +
            $"Expires: {row.ExpiryDisplay}\nBlob ID: {row.BlobId ?? "N/A"}\n" +
            $"Error: {row.ErrorCode ?? "N/A"}\nMessage: {row.Message ?? "N/A"}";
    }

    private void TryCaptureEvidenceRow(string line, string workspace)
    {
        const string marker = "[EvidenceResult] ";
        var markerIndex = line.IndexOf(marker, StringComparison.Ordinal);
        if (markerIndex < 0) return;

        try
        {
            var json = line[(markerIndex + marker.Length)..];
            var node = JsonNode.Parse(json)?.AsObject();
            if (node is null) return;

            static string Text(JsonObject obj, string key, string fallback = "unknown") =>
                obj[key]?.GetValue<string>() ?? fallback;
            static string? OptionalText(JsonObject obj, string key) =>
                obj[key] is JsonValue value && value.TryGetValue<string>(out var text) ? text : null;

            _evidenceRows.Add(new EvidenceRow(
                DateTimeOffset.Now,
                workspace,
                Text(node, "evidence_id"),
                Text(node, "operation_id"),
                Text(node, "criterion_id"),
                Text(node, "verification_state"),
                Text(node, "operation_state"),
                Text(node, "storage_status"),
                Text(node, "source_binding"),
                OptionalText(node, "source_state_id"),
                OptionalText(node, "project_context_digest"),
                Text(node, "policy_hash"),
                Text(node, "catalog_hash"),
                Text(node, "catalog_version"),
                OptionalText(node, "block_reason")));
        }
        catch
        {
            // Evidence UI never invents a record when structured metadata is malformed.
        }
    }

    private void RefreshEvidenceGrid()
    {
        var visible = _evidenceRows.AsEnumerable().Reverse().ToArray();
        EvidenceGrid.ItemsSource = visible;
        EvidenceCountText.Text = visible.Length == 0
            ? "0 captured evidence records | waiting for real evidence metadata"
            : $"{visible.Length} captured evidence record(s) | max {MaxEvidenceRows}";
    }

    private void EvidenceGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (EvidenceGrid.SelectedItem is not EvidenceRow row)
        {
            EvidenceDetailStatus.Status = PresentationStatus.Unavailable;
            EvidenceDetailText.Text = "Select an evidence record.";
            return;
        }

        EvidenceDetailStatus.Status = row.VerificationState switch
        {
            "passed" => PresentationStatus.Passed,
            "failed" => PresentationStatus.Failed,
            "stale" => PresentationStatus.Stale,
            "blocked" => PresentationStatus.Blocked,
            "not-run" => PresentationStatus.Stopped,
            "not-applicable" => PresentationStatus.Unavailable,
            _ => PresentationStatus.Warning,
        };

        EvidenceDetailText.Text =
            $"Evidence: {row.EvidenceId}\nOperation: {row.OperationId} ({row.OperationState})\nCriterion: {row.Criterion}\n" +
            $"Verification: {row.DisplayState}\nStorage: {row.StorageStatus}\nSource binding: {row.SourceBinding}\n" +
            $"Source state: {row.SourceStateId ?? "N/A"}\nProject context: {row.ProjectContextDigest ?? "N/A"}\n" +
            $"Policy hash: {row.PolicyHash}\nCatalog: {row.CatalogVersion} | {row.CatalogHash}\n" +
            $"Block reason: {row.BlockReason ?? "N/A"}";
    }

    private static bool TryCreateChangeRow(string line, string workspace, out ChangeRow change)
    {
        var lower = line.ToLowerInvariant();
        var operation = lower.Contains("apply_edits") ? "apply_edits"
            : lower.Contains("write_file") ? "write_file"
            : lower.Contains("delete_file") ? "delete_file"
            : lower.Contains("delete_directory") ? "delete_directory"
            : string.Empty;

        if (operation.Length == 0)
        {
            change = null!;
            return false;
        }

        var status = lower.Contains("changed since") || lower.Contains("stale")
            ? "Stale"
            : lower.Contains("conflict") || lower.Contains("overlapping")
                ? "Conflict"
                : lower.Contains("error") || lower.Contains("failed") || lower.Contains("refused")
                    ? "Failed"
                    : "Applied";

        var summary = line.Length <= 160 ? line : line[..157] + "...";
        change = new ChangeRow(DateTimeOffset.Now, status, workspace, operation, summary, line);
        return true;
    }

    private void RefreshChangesGrid()
    {
        var visible = _changeRows.AsEnumerable().Reverse().ToArray();
        ChangesGrid.ItemsSource = visible;
        ChangesCountText.Text = visible.Length == 0
            ? "0 captured mutation events | waiting for real write/delete/apply_edits activity"
            : $"{visible.Length} captured mutation event(s) | max {MaxChangeRows}";
    }

    private void ChangesGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ChangesGrid.SelectedItem is not ChangeRow row)
        {
            ChangeDetailStatus.Status = PresentationStatus.Unavailable;
            ChangeDetailTarget.Text = "Not emitted by runtime event";
            ChangeDetailVersion.Text = "Not emitted by runtime event";
            ChangeDetailText.Text = "Select a captured mutation event.";
            return;
        }

        ChangeDetailStatus.Status = row.Status switch
        {
            "Applied" => PresentationStatus.Passed,
            "Stale" => PresentationStatus.Stale,
            "Conflict" => PresentationStatus.Blocked,
            "Failed" => PresentationStatus.Failed,
            _ => PresentationStatus.Unavailable,
        };
        ChangeDetailTarget.Text = row.Target ?? "Not emitted by runtime event";
        ChangeDetailVersion.Text = row.VersionContext ?? "Not emitted by runtime event";
        ChangeDetailText.Text = row.Detail;
    }

    private void RefreshActivityGrid()
    {
        var filter = (ActivityFilterCombo.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "all";
        IEnumerable<ActivityRow> rows = _activityRows;
        rows = filter switch
        {
            "error" => rows.Where(row => row.Kind == "Error"),
            "runtime" => rows.Where(row => row.Kind == "Runtime"),
            "settings" => rows.Where(row => row.Kind == "Settings"),
            _ => rows,
        };

        var visible = rows.Reverse().ToArray();
        ActivityGrid.ItemsSource = visible;
        ActivityCountText.Text = $"{visible.Length} shown | {_activityRows.Count} retained (max {MaxActivityRows})";
    }

    private void ActivityFilterCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (IsLoaded) RefreshActivityGrid();
    }

    private void ActivityGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        ActivityDetailText.Text = ActivityGrid.SelectedItem is ActivityRow row
            ? $"{row.Timestamp.ToLocalTime():yyyy-MM-dd HH:mm:ss}\nType: {row.Kind}\nWorkspace: {row.Workspace}\n\n{row.Detail}"
            : "Select an activity event.";
    }

    private void ScheduleLivePresentationRefresh()
    {
        if (_livePresentationRefreshScheduled || _quitting) return;
        _livePresentationRefreshScheduled = true;
        Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(FlushLivePresentationRefresh));
    }

    private void FlushLivePresentationRefresh()
    {
        _livePresentationRefreshScheduled = false;
        if (_quitting) return;

        if (IsLoaded && MainTabs.SelectedItem == ActivityTab)
            RefreshActivityGrid();
        if (IsLoaded && MainTabs.SelectedItem == ChangesTab)
            RefreshChangesGrid();
        if (IsLoaded && MainTabs.SelectedItem == EvidenceTab)
            RefreshEvidenceGrid();
        if (IsLoaded && MainTabs.SelectedItem == RepositoryTab)
            RefreshRepositoryGrid();
        if (IsLoaded && MainTabs.SelectedItem == ArtifactsTab)
            RefreshArtifactBatchGrid();

        if (IsLoaded && MainTabs.SelectedIndex == MainTabs.Items.Count - 1)
            ApplyTextPreservingLiveTail(LogBox, _logBuffer);
    }

    private void AppendLog(string text)
    {
        RecordActivity(text);
        _logBuffer += text;
        if (_logBuffer.Length > MaxLogCharacters)
            _logBuffer = "[...older log truncated...]\n" + _logBuffer[^MaxLogCharacters..];

        ScheduleLivePresentationRefresh();
    }

    private void ShowOperationalError(
        string title,
        string failure,
        string scope,
        string stateChanged,
        string nextAction,
        string? technicalDetail = null)
    {
        ShowError(new PresentationFeedback(
            PresentationSeverity.Danger,
            title,
            $"What failed: {failure}\nScope: {scope}\nState changed: {stateChanged}\nNext: {nextAction}",
            ActionLabel: nextAction,
            TechnicalDetail: technicalDetail));
    }

    private void ShowError(PresentationFeedback feedback)
    {
        var text = feedback.Message;
        if (!string.IsNullOrWhiteSpace(feedback.TechnicalDetail))
            text += $"\n\nTechnical detail: {feedback.TechnicalDetail}";
        _lastImportantEvent = $"{feedback.Title}: {feedback.Message}";
        if (IsLoaded) HomeRecentEventText.Text = _lastImportantEvent;
        var icon = feedback.Severity == PresentationSeverity.Danger ? MessageBoxImage.Error : MessageBoxImage.Warning;
        System.Windows.MessageBox.Show(this, text, feedback.Title, MessageBoxButton.OK, icon);
    }

    private void ShowError(string message)
    {
        _lastImportantEvent = message;
        if (IsLoaded) HomeRecentEventText.Text = message;
        System.Windows.MessageBox.Show(this, message, "FileMCP", MessageBoxButton.OK, MessageBoxImage.Warning);
    }

    private void ShowAbout()
    {
        System.Windows.MessageBox.Show(
            this,
            "FileMCP 0.4.0\n\nNative Windows MCP bridge with multi-workspace C/D/E/F support for controlled local file, Git, and optional command access.",
            "About FileMCP",
            MessageBoxButton.OK,
            MessageBoxImage.Information);
    }

    private void OnClosing(object? sender, CancelEventArgs e)
    {
        if (_quitting) return;
        e.Cancel = true;
        Hide();
    }

    private void ShowFromTray()
    {
        Show();
        if (WindowState == WindowState.Minimized) WindowState = WindowState.Normal;
        Activate();
        Topmost = true;
        Topmost = false;
    }

    internal void ActivateFromSecondaryLaunch()
    {
        ShowFromTray();

        var markerPath = Environment.GetEnvironmentVariable("FILEMCP_SINGLE_INSTANCE_SMOKE_MARKER");
        if (string.IsNullOrWhiteSpace(markerPath)) return;
        try
        {
            var directory = Path.GetDirectoryName(Path.GetFullPath(markerPath));
            if (!string.IsNullOrWhiteSpace(directory)) Directory.CreateDirectory(directory);
            File.WriteAllText(markerPath, $"PASS pid={Environment.ProcessId}");
        }
        catch (Exception ex)
        {
            AppendLog($"[Desktop] Could not write single-instance smoke marker: {ex.Message}\n");
        }
    }

    public void ShutdownForSystemSession()
    {
        if (_quitting) return;
        _quitting = true;

        foreach (var runtime in _runtimes.Values)
        {
            try { runtime.ShutdownAsync().GetAwaiter().GetResult(); } catch { }
        }

        try { _observability.DisposeAsync().AsTask().GetAwaiter().GetResult(); } catch { }

        _overviewTimer.Stop();
        _trayIcon.Visible = false;
        _trayIcon.Dispose();
    }

    private async Task QuitAsync()
    {
        if (_quitting) return;
        _quitting = true;

        try
        {
            await Task.WhenAll(_runtimes.Values.Select(runtime => runtime.ShutdownAsync()));
        }
        finally
        {
            _overviewTimer.Stop();
            _trayIcon.Visible = false;
            _trayIcon.Dispose();

            foreach (var runtime in _runtimes.Values)
                await runtime.DisposeAsync();

            await _observability.DisposeAsync();

            System.Windows.Application.Current.Shutdown();
        }
    }

    private void OnPreviewKeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if ((Keyboard.Modifiers & ModifierKeys.Control) == 0) return;

        if (e.Key == Key.W)
        {
            Hide();
            e.Handled = true;
        }
        else if (e.Key == Key.OemComma)
        {
            MainTabs.SelectedItem = SettingsTab;
            ShowFromTray();
            e.Handled = true;
        }
        else if (e.Key == Key.Q)
        {
            _ = QuitAsync();
            e.Handled = true;
        }
    }

    private static System.Drawing.Icon LoadApplicationIcon()
    {
        var icon = Environment.ProcessPath is { Length: > 0 } path
            ? System.Drawing.Icon.ExtractAssociatedIcon(path)
            : null;

        return icon ?? SystemIcons.Application;
    }
}
