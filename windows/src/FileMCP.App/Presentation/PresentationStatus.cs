namespace FileMCP.App.Presentation;

public enum PresentationStatus
{
    Healthy,
    Connected,
    Starting,
    Running,
    Stopping,
    Stopped,
    Degraded,
    Warning,
    Blocked,
    Failed,
    Stale,
    Verifying,
    Passed,
    Cancelled,
    Expired,
    Unavailable,
}

public enum PresentationSeverity
{
    Neutral,
    Info,
    Success,
    Warning,
    Danger,
    Stale,
}

public sealed record PresentationStatusDescriptor(
    PresentationStatus Status,
    string Label,
    PresentationSeverity Severity,
    string IconKey);

public static class PresentationStatusCatalog
{
    public static PresentationStatusDescriptor Describe(PresentationStatus status) => status switch
    {
        PresentationStatus.Healthy => new(status, "Healthy", PresentationSeverity.Success, "status-success"),
        PresentationStatus.Connected => new(status, "Connected", PresentationSeverity.Success, "status-success"),
        PresentationStatus.Starting => new(status, "Starting", PresentationSeverity.Info, "status-progress"),
        PresentationStatus.Running => new(status, "Running", PresentationSeverity.Info, "status-running"),
        PresentationStatus.Stopping => new(status, "Stopping", PresentationSeverity.Info, "status-progress"),
        PresentationStatus.Stopped => new(status, "Stopped", PresentationSeverity.Neutral, "status-stopped"),
        PresentationStatus.Degraded => new(status, "Degraded", PresentationSeverity.Warning, "status-warning"),
        PresentationStatus.Warning => new(status, "Warning", PresentationSeverity.Warning, "status-warning"),
        PresentationStatus.Blocked => new(status, "Blocked", PresentationSeverity.Warning, "status-blocked"),
        PresentationStatus.Failed => new(status, "Failed", PresentationSeverity.Danger, "status-error"),
        PresentationStatus.Stale => new(status, "Stale", PresentationSeverity.Stale, "status-stale"),
        PresentationStatus.Verifying => new(status, "Verifying", PresentationSeverity.Info, "status-progress"),
        PresentationStatus.Passed => new(status, "Passed", PresentationSeverity.Success, "status-success"),
        PresentationStatus.Cancelled => new(status, "Cancelled", PresentationSeverity.Neutral, "status-cancelled"),
        PresentationStatus.Expired => new(status, "Expired", PresentationSeverity.Stale, "status-expired"),
        PresentationStatus.Unavailable => new(status, "Unavailable", PresentationSeverity.Neutral, "status-unavailable"),
        _ => throw new ArgumentOutOfRangeException(nameof(status), status, null),
    };

    public static string BrushResourceKey(PresentationSeverity severity) => severity switch
    {
        PresentationSeverity.Info => "FileMcpStatusInfoBrush",
        PresentationSeverity.Success => "FileMcpStatusSuccessBrush",
        PresentationSeverity.Warning => "FileMcpStatusWarningBrush",
        PresentationSeverity.Danger => "FileMcpStatusDangerBrush",
        PresentationSeverity.Stale => "FileMcpStatusStaleBrush",
        _ => "FileMcpStatusNeutralBrush",
    };
}
