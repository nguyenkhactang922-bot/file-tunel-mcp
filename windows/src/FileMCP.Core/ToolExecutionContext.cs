using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed record ToolBudgetLimits(
    int MaxVisitedEntries,
    int MaxFilesScanned,
    long MaxBytesScanned,
    int MaxOutputItems,
    int TimeoutMs)
{
    public static readonly ToolBudgetLimits ServerCaps = new(
        FileMcpConstants.MaxSearchVisited,
        FileMcpConstants.MaxSearchVisited,
        FileMcpConstants.MaxSearchContentBytesScanned,
        FileMcpConstants.MaxListEntries,
        120_000);
}

internal sealed class ToolExecutionContext : IDisposable
{
    public const string BudgetMetadataKey = "io.filemcp/budget";

    private readonly CancellationToken _parentToken;
    private readonly Func<bool> _cancellationProbe;
    private readonly CancellationTokenSource _deadlineSource;
    private int _visitedEntries;
    private int _filesScanned;
    private long _bytesScanned;
    private int _outputItems;
    private bool _truncated;
    private string _truncationReason = "none";

    private ToolExecutionContext(ToolBudgetLimits limits, CancellationToken parent, Func<bool>? cancellationProbe)
    {
        Limits = limits;
        _parentToken = parent;
        _cancellationProbe = cancellationProbe ?? (() => false);
        _deadlineSource = CancellationTokenSource.CreateLinkedTokenSource(parent);
        _deadlineSource.CancelAfter(TimeSpan.FromMilliseconds(limits.TimeoutMs));
    }

    public ToolBudgetLimits Limits { get; }
    public CancellationToken CancellationToken => _deadlineSource.Token;
    public bool Truncated => _truncated;
    public string TruncationReason => _truncationReason;
    public int RemainingFiles => Math.Max(0, Limits.MaxFilesScanned - _filesScanned);
    public long RemainingBytes => Math.Max(0, Limits.MaxBytesScanned - _bytesScanned);

    public static bool HasBudget(JsonObject? meta) => meta?[BudgetMetadataKey] is not null;

    public static ToolExecutionContext Create(JsonObject? meta, CancellationToken parent = default, Func<bool>? cancellationProbe = null)
    {
        var limits = ToolBudgetLimits.ServerCaps;
        if (meta?[BudgetMetadataKey] is JsonNode rawBudget)
        {
            if (rawBudget is not JsonObject budget)
                throw new FileMcpException($"{BudgetMetadataKey} must be an object");
            var allowed = new HashSet<string>(StringComparer.Ordinal)
            {
                "maxVisitedEntries", "maxFilesScanned", "maxBytesScanned", "maxOutputItems", "timeoutMs",
            };
            foreach (var pair in budget)
                if (!allowed.Contains(pair.Key)) throw new FileMcpException($"Unknown budget field: {pair.Key}");

            limits = new ToolBudgetLimits(
                LowerInt(budget, "maxVisitedEntries", limits.MaxVisitedEntries),
                LowerInt(budget, "maxFilesScanned", limits.MaxFilesScanned),
                LowerLong(budget, "maxBytesScanned", limits.MaxBytesScanned),
                LowerInt(budget, "maxOutputItems", limits.MaxOutputItems),
                LowerInt(budget, "timeoutMs", limits.TimeoutMs));
        }
        return new ToolExecutionContext(limits, parent, cancellationProbe);
    }

    public bool TryContinue()
    {
        if (_cancellationProbe()) return Truncate("cancelled");
        if (!CancellationToken.IsCancellationRequested) return true;
        return Truncate(_parentToken.IsCancellationRequested ? "cancelled" : "timeout");
    }

    public bool TryVisitEntry()
    {
        if (!TryContinue()) return false;
        if (_visitedEntries >= Limits.MaxVisitedEntries) return Truncate("visited_entries");
        _visitedEntries++;
        return true;
    }

    public bool TryScanFile(long bytes)
    {
        if (!TryContinue()) return false;
        if (_filesScanned >= Limits.MaxFilesScanned) return Truncate("files_scanned");
        if (bytes < 0 || bytes > Limits.MaxBytesScanned - _bytesScanned) return Truncate("bytes_scanned");
        _filesScanned++;
        _bytesScanned += bytes;
        return true;
    }

    public bool TryOutputItem()
    {
        if (!TryContinue()) return false;
        if (_outputItems >= Limits.MaxOutputItems) return Truncate("output_items");
        _outputItems++;
        return true;
    }

    public void MarkTruncated(string reason) => Truncate(reason);

    public JsonObject Usage() => new()
    {
        ["visitedEntries"] = _visitedEntries,
        ["filesScanned"] = _filesScanned,
        ["bytesScanned"] = _bytesScanned,
        ["outputItems"] = _outputItems,
        ["truncated"] = _truncated,
        ["truncationReason"] = _truncationReason,
        ["budget"] = new JsonObject
        {
            ["maxVisitedEntries"] = Limits.MaxVisitedEntries,
            ["maxFilesScanned"] = Limits.MaxFilesScanned,
            ["maxBytesScanned"] = Limits.MaxBytesScanned,
            ["maxOutputItems"] = Limits.MaxOutputItems,
            ["timeoutMs"] = Limits.TimeoutMs,
        },
    };

    public void Dispose() => _deadlineSource.Dispose();

    private bool Truncate(string reason)
    {
        _truncated = true;
        if (_truncationReason == "none") _truncationReason = string.IsNullOrWhiteSpace(reason) ? "unknown" : reason;
        return false;
    }

    private static int LowerInt(JsonObject budget, string key, int serverCap)
    {
        if (budget[key] is null) return serverCap;
        if (budget[key] is not JsonValue value || !value.TryGetValue<int>(out var requested) || requested <= 0)
            throw new FileMcpException($"Budget field {key} must be a positive integer");
        if (requested > serverCap) throw new FileMcpException($"Budget field {key} may only lower the server cap ({serverCap})");
        return requested;
    }

    private static long LowerLong(JsonObject budget, string key, long serverCap)
    {
        if (budget[key] is null) return serverCap;
        if (budget[key] is not JsonValue value || !value.TryGetValue<long>(out var requested) || requested <= 0)
            throw new FileMcpException($"Budget field {key} must be a positive integer");
        if (requested > serverCap) throw new FileMcpException($"Budget field {key} may only lower the server cap ({serverCap})");
        return requested;
    }
}
