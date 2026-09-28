namespace FileMCP.App.Presentation;

public enum PresentationDataState { FirstLoad, Refreshing, Ready, Empty, Partial, Error, Stale }
public enum NotificationSurface { Toast, Inline, Persistent, Dialog }

public sealed record PresentationFeedback(
    PresentationSeverity Severity,
    string Title,
    string Message,
    string? ActionLabel = null,
    string? TechnicalDetail = null,
    string? CorrelationReference = null);

public static class NotificationPolicy
{
    public static NotificationSurface ChooseSurface(PresentationSeverity severity, bool blocksProgress, bool requiresDecision, bool isPersistentState)
    {
        if (requiresDecision) return NotificationSurface.Dialog;
        if (isPersistentState) return NotificationSurface.Persistent;
        if (blocksProgress || severity is PresentationSeverity.Warning or PresentationSeverity.Danger or PresentationSeverity.Stale)
            return NotificationSurface.Inline;
        return NotificationSurface.Toast;
    }
}
