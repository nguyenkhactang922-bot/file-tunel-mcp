using System.Diagnostics;
using Microsoft.Data.Sqlite;

namespace FileMCP.Core;

internal interface ITelemetryDeltaStore
{
    Task InitializeAsync(CancellationToken cancellationToken = default);
    Task UpsertDeltasAsync(DateTimeOffset capturedAtUtc, IReadOnlyDictionary<string, UsageCounters> deltas, CancellationToken cancellationToken = default);
}

internal sealed class TelemetrySqliteStore : ITelemetryDeltaStore
{
    public const int SchemaVersion = 1;
    private readonly string _databasePath;
    private readonly SemaphoreSlim _initializeGate = new(1, 1);
    private volatile bool _initialized;

    public TelemetrySqliteStore(string? databasePath = null)
    {
        _databasePath = databasePath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FileMCP",
            "observability-v1.sqlite3");
    }

    public string DatabasePath => _databasePath;

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        if (_initialized) return;
        await _initializeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_initialized) return;
            var directory = Path.GetDirectoryName(Path.GetFullPath(_databasePath));
            if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);

            await using var connection = await OpenConfiguredConnectionAsync(cancellationToken).ConfigureAwait(false);
            await ExecuteAsync(connection, "PRAGMA journal_mode=WAL;", cancellationToken).ConfigureAwait(false);
            await CreateSchemaAsync(connection, cancellationToken).ConfigureAwait(false);
            _initialized = true;
        }
        finally
        {
            _initializeGate.Release();
        }
    }

    public async Task UpsertDeltasAsync(
        DateTimeOffset capturedAtUtc,
        IReadOnlyDictionary<string, UsageCounters> deltas,
        CancellationToken cancellationToken = default)
    {
        if (deltas.Count == 0 || deltas.Values.All(value => value.IsZero)) return;
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await using var connection = await OpenConfiguredConnectionAsync(cancellationToken).ConfigureAwait(false);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var utc = capturedAtUtc.ToUniversalTime();
            var unix = utc.ToUnixTimeSeconds();
            var buckets = new (string Table, long Epoch)[]
            {
                ("usage_minute", FloorBucket(unix, 60)),
                ("usage_hour", FloorBucket(unix, 3_600)),
                ("usage_day", FloorBucket(unix, 86_400)),
            };

            foreach (var pair in deltas)
            {
                if (pair.Value.IsZero) continue;
                foreach (var bucket in buckets)
                    await UpsertBucketAsync(connection, transaction, bucket.Table, pair.Key, bucket.Epoch, pair.Value, cancellationToken).ConfigureAwait(false);
            }
            await transaction.CommitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None).ConfigureAwait(false);
            throw;
        }
    }

    internal static long FloorBucket(long unixSeconds, long bucketSeconds) =>
        unixSeconds - Mod(unixSeconds, bucketSeconds);

    private async Task<SqliteConnection> OpenConfiguredConnectionAsync(CancellationToken cancellationToken)
    {
        var builder = new SqliteConnectionStringBuilder
        {
            DataSource = _databasePath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Shared,
            Pooling = true,
        };
        var connection = new SqliteConnection(builder.ToString());
        await connection.OpenAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await ExecuteAsync(connection, "PRAGMA busy_timeout=5000; PRAGMA synchronous=NORMAL; PRAGMA foreign_keys=ON;", cancellationToken).ConfigureAwait(false);
            return connection;
        }
        catch
        {
            await connection.DisposeAsync().ConfigureAwait(false);
            throw;
        }
    }

    private static async Task CreateSchemaAsync(SqliteConnection connection, CancellationToken cancellationToken)
    {
        const string schema = """
            CREATE TABLE IF NOT EXISTS telemetry_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS usage_minute (
                workspace_key TEXT NOT NULL,
                bucket_epoch INTEGER NOT NULL,
                mcp_requests INTEGER NOT NULL DEFAULT 0,
                tool_calls INTEGER NOT NULL DEFAULT 0,
                execution_tasks INTEGER NOT NULL DEFAULT 0,
                request_bytes INTEGER NOT NULL DEFAULT 0,
                response_bytes INTEGER NOT NULL DEFAULT 0,
                tokens_in_est INTEGER NOT NULL DEFAULT 0,
                tokens_out_est INTEGER NOT NULL DEFAULT 0,
                errors INTEGER NOT NULL DEFAULT 0,
                read_calls INTEGER NOT NULL DEFAULT 0,
                write_calls INTEGER NOT NULL DEFAULT 0,
                command_calls INTEGER NOT NULL DEFAULT 0,
                git_calls INTEGER NOT NULL DEFAULT 0,
                skill_calls INTEGER NOT NULL DEFAULT 0,
                other_calls INTEGER NOT NULL DEFAULT 0,
                total_latency_us INTEGER NOT NULL DEFAULT 0,
                max_latency_us INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (workspace_key, bucket_epoch)
            );

            CREATE TABLE IF NOT EXISTS usage_hour AS SELECT * FROM usage_minute WHERE 0;
            CREATE UNIQUE INDEX IF NOT EXISTS ux_usage_hour_workspace_bucket ON usage_hour(workspace_key, bucket_epoch);
            CREATE TABLE IF NOT EXISTS usage_day AS SELECT * FROM usage_minute WHERE 0;
            CREATE UNIQUE INDEX IF NOT EXISTS ux_usage_day_workspace_bucket ON usage_day(workspace_key, bucket_epoch);

            CREATE TABLE IF NOT EXISTS logical_sessions (
                session_hash TEXT PRIMARY KEY,
                created_epoch INTEGER NOT NULL,
                last_seen_epoch INTEGER NOT NULL,
                client_name TEXT NULL,
                state TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS logical_session_workspace (
                session_hash TEXT NOT NULL,
                workspace_key TEXT NOT NULL,
                first_seen_epoch INTEGER NOT NULL,
                last_seen_epoch INTEGER NOT NULL,
                mcp_requests INTEGER NOT NULL DEFAULT 0,
                tool_calls INTEGER NOT NULL DEFAULT 0,
                execution_tasks INTEGER NOT NULL DEFAULT 0,
                request_bytes INTEGER NOT NULL DEFAULT 0,
                response_bytes INTEGER NOT NULL DEFAULT 0,
                tokens_in_est INTEGER NOT NULL DEFAULT 0,
                tokens_out_est INTEGER NOT NULL DEFAULT 0,
                errors INTEGER NOT NULL DEFAULT 0,
                read_calls INTEGER NOT NULL DEFAULT 0,
                write_calls INTEGER NOT NULL DEFAULT 0,
                command_calls INTEGER NOT NULL DEFAULT 0,
                git_calls INTEGER NOT NULL DEFAULT 0,
                skill_calls INTEGER NOT NULL DEFAULT 0,
                other_calls INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (session_hash, workspace_key),
                FOREIGN KEY (session_hash) REFERENCES logical_sessions(session_hash) ON DELETE CASCADE
            );
            """;
        await ExecuteAsync(connection, schema, cancellationToken).ConfigureAwait(false);

        var existingVersion = await ReadMetaAsync(connection, "schema_version", cancellationToken).ConfigureAwait(false);
        if (existingVersion is not null && (!int.TryParse(existingVersion, out var parsed) || parsed > SchemaVersion))
            throw new FileMcpException($"Observability database schema '{existingVersion}' is newer than supported version {SchemaVersion}.");

        if (existingVersion is null)
            await WriteMetaAsync(connection, "schema_version", SchemaVersion.ToString(), cancellationToken).ConfigureAwait(false);
        else if (existingVersion != SchemaVersion.ToString())
            await MigrateAsync(connection, int.Parse(existingVersion), cancellationToken).ConfigureAwait(false);

        await WriteMetaAsync(connection, "token_estimator", McpTokenEstimator.EstimatorId, cancellationToken).ConfigureAwait(false);
    }

    private static Task MigrateAsync(SqliteConnection connection, int fromVersion, CancellationToken cancellationToken)
    {
        if (fromVersion == SchemaVersion) return Task.CompletedTask;
        throw new FileMcpException($"Unsupported observability database migration from schema {fromVersion} to {SchemaVersion}.");
    }

    private static async Task UpsertBucketAsync(
        SqliteConnection connection,
        System.Data.Common.DbTransaction transaction,
        string table,
        string workspaceKey,
        long bucketEpoch,
        UsageCounters delta,
        CancellationToken cancellationToken)
    {
        var allowed = table is "usage_minute" or "usage_hour" or "usage_day";
        if (!allowed) throw new ArgumentOutOfRangeException(nameof(table));

        await using var command = connection.CreateCommand();
        command.Transaction = (SqliteTransaction)transaction;
        command.CommandText = $"""
            INSERT INTO {table} (
                workspace_key, bucket_epoch, mcp_requests, tool_calls, execution_tasks,
                request_bytes, response_bytes, tokens_in_est, tokens_out_est, errors,
                read_calls, write_calls, command_calls, git_calls, skill_calls, other_calls,
                total_latency_us, max_latency_us
            ) VALUES (
                $workspace, $bucket, $mcp_requests, $tool_calls, $execution_tasks,
                $request_bytes, $response_bytes, $tokens_in_est, $tokens_out_est, $errors,
                $read_calls, $write_calls, $command_calls, $git_calls, $skill_calls, $other_calls,
                $total_latency_us, $max_latency_us
            )
            ON CONFLICT(workspace_key, bucket_epoch) DO UPDATE SET
                mcp_requests = mcp_requests + excluded.mcp_requests,
                tool_calls = tool_calls + excluded.tool_calls,
                execution_tasks = execution_tasks + excluded.execution_tasks,
                request_bytes = request_bytes + excluded.request_bytes,
                response_bytes = response_bytes + excluded.response_bytes,
                tokens_in_est = tokens_in_est + excluded.tokens_in_est,
                tokens_out_est = tokens_out_est + excluded.tokens_out_est,
                errors = errors + excluded.errors,
                read_calls = read_calls + excluded.read_calls,
                write_calls = write_calls + excluded.write_calls,
                command_calls = command_calls + excluded.command_calls,
                git_calls = git_calls + excluded.git_calls,
                skill_calls = skill_calls + excluded.skill_calls,
                other_calls = other_calls + excluded.other_calls,
                total_latency_us = total_latency_us + excluded.total_latency_us,
                max_latency_us = MAX(max_latency_us, excluded.max_latency_us);
            """;
        command.Parameters.AddWithValue("$workspace", workspaceKey);
        command.Parameters.AddWithValue("$bucket", bucketEpoch);
        command.Parameters.AddWithValue("$mcp_requests", delta.McpRequests);
        command.Parameters.AddWithValue("$tool_calls", delta.ToolCalls);
        command.Parameters.AddWithValue("$execution_tasks", delta.ExecutionTasks);
        command.Parameters.AddWithValue("$request_bytes", delta.RequestBytes);
        command.Parameters.AddWithValue("$response_bytes", delta.ResponseBytes);
        command.Parameters.AddWithValue("$tokens_in_est", delta.TokensInEst);
        command.Parameters.AddWithValue("$tokens_out_est", delta.TokensOutEst);
        command.Parameters.AddWithValue("$errors", delta.Errors);
        command.Parameters.AddWithValue("$read_calls", delta.ReadCalls);
        command.Parameters.AddWithValue("$write_calls", delta.WriteCalls);
        command.Parameters.AddWithValue("$command_calls", delta.CommandCalls);
        command.Parameters.AddWithValue("$git_calls", delta.GitCalls);
        command.Parameters.AddWithValue("$skill_calls", delta.SkillCalls);
        command.Parameters.AddWithValue("$other_calls", delta.OtherCalls);
        command.Parameters.AddWithValue("$total_latency_us", TicksToMicroseconds(delta.TotalLatencyTicks));
        command.Parameters.AddWithValue("$max_latency_us", TicksToMicroseconds(delta.MaxLatencyTicks));
        await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task<string?> ReadMetaAsync(SqliteConnection connection, string key, CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT value FROM telemetry_meta WHERE key = $key;";
        command.Parameters.AddWithValue("$key", key);
        return (string?)await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task WriteMetaAsync(SqliteConnection connection, string key, string value, CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = "INSERT INTO telemetry_meta(key, value) VALUES($key, $value) ON CONFLICT(key) DO UPDATE SET value = excluded.value;";
        command.Parameters.AddWithValue("$key", key);
        command.Parameters.AddWithValue("$value", value);
        await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    private static async Task ExecuteAsync(SqliteConnection connection, string sql, CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    private static long TicksToMicroseconds(long ticks)
    {
        if (ticks <= 0) return 0;
        return (long)((decimal)ticks * 1_000_000m / Stopwatch.Frequency);
    }

    private static long Mod(long value, long divisor)
    {
        var result = value % divisor;
        return result < 0 ? result + divisor : result;
    }
}

internal sealed class TelemetryWriter : IAsyncDisposable
{
    private readonly IReadOnlyList<WorkspaceUsageMeter> _meters;
    private readonly ITelemetryDeltaStore _store;
    private readonly TimeSpan _interval;
    private readonly Action<string>? _log;
    private readonly SemaphoreSlim _flushGate = new(1, 1);
    private readonly Dictionary<string, UsageCounters> _pending = new(StringComparer.OrdinalIgnoreCase);
    private CancellationTokenSource? _cts;
    private Task? _loop;

    public TelemetryWriter(
        IEnumerable<WorkspaceUsageMeter> meters,
        ITelemetryDeltaStore store,
        TimeSpan? interval = null,
        Action<string>? log = null)
    {
        _meters = meters.ToArray();
        _store = store;
        _interval = interval ?? TimeSpan.FromSeconds(1);
        if (_interval <= TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(interval));
        _log = log;
    }

    public async Task StartAsync(CancellationToken cancellationToken = default)
    {
        if (_loop is not null) return;
        await _store.InitializeAsync(cancellationToken).ConfigureAwait(false);
        _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        _loop = RunAsync(_cts.Token);
    }

    public async Task FlushOnceAsync(DateTimeOffset capturedAtUtc, CancellationToken cancellationToken = default)
    {
        await _flushGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            CollectPending();
            if (_pending.Count == 0) return;
            await _store.InitializeAsync(cancellationToken).ConfigureAwait(false);
            await _store.UpsertDeltasAsync(capturedAtUtc, _pending, cancellationToken).ConfigureAwait(false);
            _pending.Clear();
        }
        finally
        {
            _flushGate.Release();
        }
    }

    internal IReadOnlyDictionary<string, UsageCounters> PendingSnapshotForTests() =>
        _pending.ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.OrdinalIgnoreCase);

    private void CollectPending()
    {
        foreach (var meter in _meters)
        {
            var delta = meter.DrainDelta();
            if (delta.IsZero) continue;
            _pending[meter.WorkspaceKey] = _pending.TryGetValue(meter.WorkspaceKey, out var existing)
                ? existing + delta
                : delta;
        }
    }

    private async Task RunAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(_interval);
        try
        {
            while (await timer.WaitForNextTickAsync(cancellationToken).ConfigureAwait(false))
            {
                try { await FlushOnceAsync(DateTimeOffset.UtcNow, cancellationToken).ConfigureAwait(false); }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { return; }
                catch (Exception ex) { _log?.Invoke($"[Telemetry] flush failed: {ex.Message}\n"); }
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { }
    }

    public async ValueTask DisposeAsync()
    {
        if (_cts is not null)
        {
            _cts.Cancel();
            if (_loop is not null)
            {
                try { await _loop.ConfigureAwait(false); } catch (OperationCanceledException) { }
            }
            try { await FlushOnceAsync(DateTimeOffset.UtcNow).ConfigureAwait(false); }
            catch (Exception ex) { _log?.Invoke($"[Telemetry] final flush failed: {ex.Message}\n"); }
            _cts.Dispose();
            _cts = null;
            _loop = null;
        }
        _flushGate.Dispose();
    }
}