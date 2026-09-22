namespace FileMCP.Core;

public enum LogicalSessionActivityState
{
    Active,
    Idle,
    Stale,
}

public sealed record LogicalSessionWorkspaceSnapshot(
    string WorkspaceKey,
    DateTimeOffset FirstSeenUtc,
    DateTimeOffset LastSeenUtc,
    UsageCounters Usage);

public sealed record LogicalSessionSnapshot(
    string SessionHash,
    DateTimeOffset CreatedUtc,
    DateTimeOffset LastSeenUtc,
    int InFlightCalls,
    LogicalSessionActivityState State,
    IReadOnlyDictionary<string, LogicalSessionWorkspaceSnapshot> Workspaces);

public sealed record UnboundSessionSnapshot(
    string WorkspaceKey,
    DateTimeOffset FirstSeenUtc,
    DateTimeOffset LastSeenUtc,
    int InFlightCalls,
    LogicalSessionActivityState State,
    UsageCounters Usage);

internal readonly record struct LogicalSessionCallToken(
    string WorkspaceKey,
    string? SessionHash,
    DateTimeOffset StartedUtc,
    long RequestBytes,
    string? ToolName);

internal sealed record LogicalSessionPersistenceDelta(
    string SessionHash,
    string WorkspaceKey,
    long CreatedEpoch,
    long FirstSeenEpoch,
    long LastSeenEpoch,
    string State,
    UsageCounters Usage);

internal sealed record UnboundSessionPersistenceDelta(
    string WorkspaceKey,
    long FirstSeenEpoch,
    long LastSeenEpoch,
    string State,
    UsageCounters Usage);

internal sealed record LogicalSessionPersistenceBatch(
    IReadOnlyList<LogicalSessionPersistenceDelta> Sessions,
    IReadOnlyList<UnboundSessionPersistenceDelta> Unbound)
{
    public bool IsEmpty => Sessions.Count == 0 && Unbound.Count == 0;
}

public sealed class LogicalSessionRegistry
{
    public static readonly TimeSpan ActiveIdleThreshold = TimeSpan.FromSeconds(45);
    public static readonly TimeSpan StaleThreshold = TimeSpan.FromMinutes(30);

    private sealed class WorkspaceEntry
    {
        public required DateTimeOffset FirstSeenUtc;
        public required DateTimeOffset LastSeenUtc;
        public UsageCounters Usage;
        public UsageCounters PendingUsage;
    }

    private sealed class SessionEntry
    {
        public required string Hash;
        public required DateTimeOffset CreatedUtc;
        public required DateTimeOffset LastSeenUtc;
        public int InFlight;
        public readonly Dictionary<string, WorkspaceEntry> Workspaces = new(StringComparer.OrdinalIgnoreCase);
        public bool PendingState;
        public string? LastDrainedState;
    }

    private sealed class UnboundEntry
    {
        public required DateTimeOffset FirstSeenUtc;
        public required DateTimeOffset LastSeenUtc;
        public int InFlight;
        public UsageCounters Usage;
        public UsageCounters PendingUsage;
        public bool PendingState;
        public string? LastDrainedState;
    }

    private readonly object _gate = new();
    private readonly Dictionary<string, SessionEntry> _sessions = new(StringComparer.Ordinal);
    private readonly Dictionary<string, UnboundEntry> _unbound = new(StringComparer.OrdinalIgnoreCase);

    public void RegisterSession(string sessionHash, DateTimeOffset? nowUtc = null)
    {
        ValidateHash(sessionHash);
        var now = (nowUtc ?? DateTimeOffset.UtcNow).ToUniversalTime();
        lock (_gate)
        {
            if (_sessions.TryGetValue(sessionHash, out var existing))
            {
                if (now > existing.LastSeenUtc) existing.LastSeenUtc = now;
                existing.PendingState = true;
                return;
            }
            _sessions[sessionHash] = new SessionEntry
            {
                Hash = sessionHash,
                CreatedUtc = now,
                LastSeenUtc = now,
                PendingState = true,
            };
        }
    }

    internal LogicalSessionCallToken BeginToolCall(
        string workspaceKey,
        string? sessionHash,
        long requestBytes,
        string? toolName,
        DateTimeOffset? nowUtc = null)
    {
        var key = NormalizeWorkspaceKey(workspaceKey);
        var now = (nowUtc ?? DateTimeOffset.UtcNow).ToUniversalTime();
        var bytes = Math.Max(0, requestBytes);
        lock (_gate)
        {
            if (sessionHash is not null)
            {
                ValidateHash(sessionHash);
                if (!_sessions.TryGetValue(sessionHash, out var session))
                {
                    session = new SessionEntry { Hash = sessionHash, CreatedUtc = now, LastSeenUtc = now, PendingState = true };
                    _sessions[sessionHash] = session;
                }
                session.InFlight++;
                session.LastSeenUtc = Max(session.LastSeenUtc, now);
                session.PendingState = true;
                var workspace = GetOrCreateWorkspace(session.Workspaces, key, now);
                workspace.LastSeenUtc = Max(workspace.LastSeenUtc, now);
            }
            else
            {
                var unbound = GetOrCreateUnbound(key, now);
                unbound.InFlight++;
                unbound.LastSeenUtc = Max(unbound.LastSeenUtc, now);
                unbound.PendingState = true;
            }
        }
        return new LogicalSessionCallToken(key, sessionHash, now, bytes, toolName);
    }

    internal void CompleteToolCall(
        LogicalSessionCallToken token,
        long responseBytes,
        bool isError,
        long latencyTicks,
        DateTimeOffset? nowUtc = null)
    {
        var now = (nowUtc ?? DateTimeOffset.UtcNow).ToUniversalTime();
        var delta = CountersForCall(token.RequestBytes, Math.Max(0, responseBytes), token.ToolName, isError, Math.Max(0, latencyTicks));
        lock (_gate)
        {
            if (token.SessionHash is not null && _sessions.TryGetValue(token.SessionHash, out var session))
            {
                session.InFlight = Math.Max(0, session.InFlight - 1);
                session.LastSeenUtc = Max(session.LastSeenUtc, now);
                session.PendingState = true;
                var workspace = GetOrCreateWorkspace(session.Workspaces, token.WorkspaceKey, token.StartedUtc);
                workspace.LastSeenUtc = Max(workspace.LastSeenUtc, now);
                workspace.Usage += delta;
                workspace.PendingUsage += delta;
            }
            else
            {
                var unbound = GetOrCreateUnbound(token.WorkspaceKey, token.StartedUtc);
                unbound.InFlight = Math.Max(0, unbound.InFlight - 1);
                unbound.LastSeenUtc = Max(unbound.LastSeenUtc, now);
                unbound.Usage += delta;
                unbound.PendingUsage += delta;
                unbound.PendingState = true;
            }
        }
    }

    public IReadOnlyList<LogicalSessionSnapshot> Snapshot(DateTimeOffset? nowUtc = null, bool includeStale = false)
    {
        var now = (nowUtc ?? DateTimeOffset.UtcNow).ToUniversalTime();
        lock (_gate)
        {
            return _sessions.Values
                .Select(entry => ToSnapshot(entry, now))
                .Where(entry => includeStale || entry.State != LogicalSessionActivityState.Stale)
                .OrderByDescending(entry => entry.LastSeenUtc)
                .ToArray();
        }
    }

    public IReadOnlyList<UnboundSessionSnapshot> UnboundSnapshot(DateTimeOffset? nowUtc = null, bool includeStale = false)
    {
        var now = (nowUtc ?? DateTimeOffset.UtcNow).ToUniversalTime();
        lock (_gate)
        {
            return _unbound.Select(pair =>
                {
                    var state = StateFor(pair.Value.InFlight, pair.Value.LastSeenUtc, now);
                    return new UnboundSessionSnapshot(pair.Key, pair.Value.FirstSeenUtc, pair.Value.LastSeenUtc, pair.Value.InFlight, state, pair.Value.Usage);
                })
                .Where(entry => includeStale || entry.State != LogicalSessionActivityState.Stale)
                .OrderByDescending(entry => entry.LastSeenUtc)
                .ToArray();
        }
    }

    internal LogicalSessionPersistenceBatch DrainPersistence(DateTimeOffset? nowUtc = null)
    {
        var now = (nowUtc ?? DateTimeOffset.UtcNow).ToUniversalTime();
        lock (_gate)
        {
            var sessions = new List<LogicalSessionPersistenceDelta>();
            foreach (var session in _sessions.Values)
            {
                var state = StateFor(session.InFlight, session.LastSeenUtc, now).ToString().ToLowerInvariant();
                foreach (var workspace in session.Workspaces)
                {
                    if (workspace.Value.PendingUsage.IsZero && !session.PendingState && session.LastDrainedState == state) continue;
                    sessions.Add(new LogicalSessionPersistenceDelta(
                        session.Hash,
                        workspace.Key,
                        session.CreatedUtc.ToUnixTimeSeconds(),
                        workspace.Value.FirstSeenUtc.ToUnixTimeSeconds(),
                        workspace.Value.LastSeenUtc.ToUnixTimeSeconds(),
                        state,
                        workspace.Value.PendingUsage));
                    workspace.Value.PendingUsage = default;
                }
                session.PendingState = false;
                session.LastDrainedState = state;
            }

            var unbound = new List<UnboundSessionPersistenceDelta>();
            foreach (var pair in _unbound)
            {
                var entry = pair.Value;
                var currentState = StateFor(entry.InFlight, entry.LastSeenUtc, now).ToString().ToLowerInvariant();
                if (entry.PendingUsage.IsZero && !entry.PendingState && entry.LastDrainedState == currentState) continue;
                unbound.Add(new UnboundSessionPersistenceDelta(
                    pair.Key,
                    entry.FirstSeenUtc.ToUnixTimeSeconds(),
                    entry.LastSeenUtc.ToUnixTimeSeconds(),
                    currentState,
                    entry.PendingUsage));
                entry.PendingUsage = default;
                entry.PendingState = false;
                entry.LastDrainedState = currentState;
            }
            return new LogicalSessionPersistenceBatch(sessions, unbound);
        }
    }

    internal void RestorePersistence(LogicalSessionPersistenceBatch batch)
    {
        lock (_gate)
        {
            foreach (var delta in batch.Sessions)
            {
                if (!_sessions.TryGetValue(delta.SessionHash, out var session))
                {
                    session = new SessionEntry
                    {
                        Hash = delta.SessionHash,
                        CreatedUtc = DateTimeOffset.FromUnixTimeSeconds(delta.CreatedEpoch),
                        LastSeenUtc = DateTimeOffset.FromUnixTimeSeconds(delta.LastSeenEpoch),
                    };
                    _sessions[delta.SessionHash] = session;
                }
                session.PendingState = true;
                var workspace = GetOrCreateWorkspace(session.Workspaces, delta.WorkspaceKey, DateTimeOffset.FromUnixTimeSeconds(delta.FirstSeenEpoch));
                workspace.LastSeenUtc = Max(workspace.LastSeenUtc, DateTimeOffset.FromUnixTimeSeconds(delta.LastSeenEpoch));
                workspace.PendingUsage += delta.Usage;
            }
            foreach (var delta in batch.Unbound)
            {
                var entry = GetOrCreateUnbound(delta.WorkspaceKey, DateTimeOffset.FromUnixTimeSeconds(delta.FirstSeenEpoch));
                entry.LastSeenUtc = Max(entry.LastSeenUtc, DateTimeOffset.FromUnixTimeSeconds(delta.LastSeenEpoch));
                entry.PendingUsage += delta.Usage;
                entry.PendingState = true;
            }
        }
    }

    public static LogicalSessionActivityState StateFor(int inFlightCalls, DateTimeOffset lastSeenUtc, DateTimeOffset nowUtc)
    {
        if (inFlightCalls > 0) return LogicalSessionActivityState.Active;
        var idle = nowUtc.ToUniversalTime() - lastSeenUtc.ToUniversalTime();
        if (idle <= ActiveIdleThreshold) return LogicalSessionActivityState.Active;
        if (idle <= StaleThreshold) return LogicalSessionActivityState.Idle;
        return LogicalSessionActivityState.Stale;
    }

    private static LogicalSessionSnapshot ToSnapshot(SessionEntry entry, DateTimeOffset now)
    {
        var workspaces = entry.Workspaces.ToDictionary(
            pair => pair.Key,
            pair => new LogicalSessionWorkspaceSnapshot(pair.Key, pair.Value.FirstSeenUtc, pair.Value.LastSeenUtc, pair.Value.Usage),
            StringComparer.OrdinalIgnoreCase);
        return new LogicalSessionSnapshot(entry.Hash, entry.CreatedUtc, entry.LastSeenUtc, entry.InFlight, StateFor(entry.InFlight, entry.LastSeenUtc, now), workspaces);
    }

    private static WorkspaceEntry GetOrCreateWorkspace(Dictionary<string, WorkspaceEntry> workspaces, string key, DateTimeOffset now)
    {
        if (workspaces.TryGetValue(key, out var existing)) return existing;
        var created = new WorkspaceEntry { FirstSeenUtc = now, LastSeenUtc = now };
        workspaces[key] = created;
        return created;
    }

    private UnboundEntry GetOrCreateUnbound(string key, DateTimeOffset now)
    {
        if (_unbound.TryGetValue(key, out var existing)) return existing;
        var created = new UnboundEntry { FirstSeenUtc = now, LastSeenUtc = now, PendingState = true };
        _unbound[key] = created;
        return created;
    }

    private static UsageCounters CountersForCall(long requestBytes, long responseBytes, string? toolName, bool isError, long latencyTicks)
    {
        var classification = ToolUsageClassifier.Classify(toolName);
        return new UsageCounters(
            1,
            1,
            classification.IsExecutionTask ? 1 : 0,
            requestBytes,
            responseBytes,
            McpTokenEstimator.EstimateFromUtf8Bytes(requestBytes),
            McpTokenEstimator.EstimateFromUtf8Bytes(responseBytes),
            isError ? 1 : 0,
            classification.Category == ToolUsageCategory.Read ? 1 : 0,
            classification.Category == ToolUsageCategory.Write ? 1 : 0,
            classification.Category == ToolUsageCategory.Command ? 1 : 0,
            classification.Category == ToolUsageCategory.Git ? 1 : 0,
            classification.Category == ToolUsageCategory.Skill ? 1 : 0,
            classification.Category == ToolUsageCategory.Other ? 1 : 0,
            latencyTicks,
            latencyTicks);
    }

    private static string NormalizeWorkspaceKey(string workspaceKey)
    {
        if (string.IsNullOrWhiteSpace(workspaceKey)) throw new ArgumentException("Workspace key cannot be empty.", nameof(workspaceKey));
        return workspaceKey.Trim().ToUpperInvariant();
    }

    private static void ValidateHash(string sessionHash)
    {
        if (sessionHash.Length != 64 || !sessionHash.All(ch => char.IsAsciiHexDigit(ch)))
            throw new ArgumentException("Logical session hash must be a lowercase or uppercase SHA-256 hex digest.", nameof(sessionHash));
    }

    private static DateTimeOffset Max(DateTimeOffset left, DateTimeOffset right) => left >= right ? left : right;
}