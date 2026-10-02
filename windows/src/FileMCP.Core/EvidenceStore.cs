using Microsoft.Data.Sqlite;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace FileMCP.Core;

internal sealed record EvidenceBegin(
    string EvidenceId,
    string OperationId,
    string WorkspaceFingerprint,
    string ToolName,
    string CriterionId,
    long StartedEpochMs,
    string BackendId,
    string BackendMetadataJson,
    long PolicyGeneration,
    string PolicyHash,
    string CatalogHash,
    string CatalogVersion);

internal sealed record EvidenceCompletion(
    string EvidenceId,
    long EndedEpochMs,
    string OperationState,
    string VerificationState,
    string? SourceStateJson,
    string? SourceStateId,
    string? ProjectContextDigest,
    long PolicyGeneration,
    string PolicyHash,
    string CatalogHash,
    string CatalogVersion,
    int? ExitCode,
    bool TimedOut,
    bool Cancelled,
    bool Truncated);

internal sealed record EvidenceRecord(
    string EvidenceId,
    string OperationId,
    string WorkspaceFingerprint,
    string ToolName,
    string CriterionId,
    long StartedEpochMs,
    long? EndedEpochMs,
    string OperationState,
    string VerificationState,
    string BackendId,
    string BackendMetadataJson,
    string? SourceStateJson,
    string? SourceStateId,
    string? ProjectContextDigest,
    long PolicyGeneration,
    string PolicyHash,
    string CatalogHash,
    string CatalogVersion,
    int? ExitCode,
    bool TimedOut,
    bool Cancelled,
    bool Truncated);

internal sealed class EvidenceStore
{
    public const int SchemaVersion = 2;
    public static readonly TimeSpan DefaultRetention = TimeSpan.FromDays(30);
    public const int DefaultMaxRecords = 10_000;
    public const long DefaultMaxStoreBytes = 32L * 1024 * 1024;
    public const int MaxSourceStateJsonBytes = 256 * 1024;
    public const int MaxBackendMetadataJsonBytes = 16 * 1024;

    private readonly string _databasePath;
    private readonly TimeSpan _retention;
    private readonly int _maxRecords;
    private readonly long _maxStoreBytes;
    private readonly Func<DateTimeOffset> _utcNow;
    private readonly SemaphoreSlim _initializeGate = new(1, 1);
    private readonly SemaphoreSlim _writeGate = new(1, 1);
    private volatile bool _initialized;

    public EvidenceStore(
        string? databasePath = null,
        TimeSpan? retention = null,
        int maxRecords = DefaultMaxRecords,
        long maxStoreBytes = DefaultMaxStoreBytes,
        Func<DateTimeOffset>? utcNow = null)
    {
        if (maxRecords < 1) throw new ArgumentOutOfRangeException(nameof(maxRecords));
        if (maxStoreBytes < 64 * 1024) throw new ArgumentOutOfRangeException(nameof(maxStoreBytes));
        _databasePath = databasePath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FileMCP",
            "evidence-v1.sqlite3");
        _retention = retention ?? DefaultRetention;
        if (_retention <= TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(retention));
        _maxRecords = maxRecords;
        _maxStoreBytes = maxStoreBytes;
        _utcNow = utcNow ?? (() => DateTimeOffset.UtcNow);
    }

    public string DatabasePath => _databasePath;

    public static string NewEvidenceId() => "ev_" + Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant();

    public static string WorkspaceFingerprint(string workspaceRoot)
    {
        var canonical = Path.GetFullPath(workspaceRoot).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (OperatingSystem.IsWindows()) canonical = canonical.ToUpperInvariant();
        return "sha256:" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
    }

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
            await ExecuteAsync(connection, "PRAGMA auto_vacuum=FULL;", cancellationToken).ConfigureAwait(false);
            await ExecuteAsync(connection, "PRAGMA journal_mode=WAL;", cancellationToken).ConfigureAwait(false);
            await ExecuteAsync(connection, "PRAGMA wal_autocheckpoint=32;", cancellationToken).ConfigureAwait(false);
            await ExecuteAsync(connection, "PRAGMA journal_size_limit=1048576;", cancellationToken).ConfigureAwait(false);
            await CreateSchemaAsync(connection, cancellationToken).ConfigureAwait(false);
            await ConfigurePageQuotaAsync(connection, cancellationToken).ConfigureAwait(false);

            await using (var recover = connection.CreateCommand())
            {
                recover.CommandText = """
                    UPDATE evidence_records
                    SET operation_state='unknown', verification_state='unknown', ended_epoch_ms=COALESCE(ended_epoch_ms,$now)
                    WHERE operation_state='running';
                    """;
                recover.Parameters.AddWithValue("$now", _utcNow().ToUnixTimeMilliseconds());
                await recover.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            }
            await CleanupRetentionAndQuotaAsync(connection, reserveRecords: 0, cancellationToken).ConfigureAwait(false);
            _initialized = true;
        }
        finally
        {
            _initializeGate.Release();
        }
    }

    public async Task BeginAsync(EvidenceBegin begin, CancellationToken cancellationToken = default)
    {
        ValidateBegin(begin);
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await using var connection = await OpenConfiguredConnectionAsync(cancellationToken).ConfigureAwait(false);
            await CleanupRetentionAndQuotaAsync(connection, reserveRecords: 1, cancellationToken).ConfigureAwait(false);
            await EnsureStoreHasCapacityAsync(estimatedAdditionalBytes: 4096, cancellationToken).ConfigureAwait(false);

            await using var command = connection.CreateCommand();
            command.CommandText = """
                INSERT INTO evidence_records(
                    evidence_id,operation_id,workspace_fingerprint,tool_name,criterion_id,
                    started_epoch_ms,ended_epoch_ms,operation_state,verification_state,backend_id,backend_metadata_json,
                    source_state_json,source_state_id,project_context_digest,
                    policy_generation,policy_hash,catalog_hash,catalog_version,
                    exit_code,timed_out,cancelled,truncated)
                VALUES(
                    $evidence,$operation,$workspace,$tool,$criterion,
                    $started,NULL,'running','not-run',$backend,$backendMetadata,
                    NULL,NULL,NULL,
                    $policyGeneration,$policyHash,$catalogHash,$catalogVersion,
                    NULL,0,0,0);
                """;
            command.Parameters.AddWithValue("$evidence", begin.EvidenceId);
            command.Parameters.AddWithValue("$operation", begin.OperationId);
            command.Parameters.AddWithValue("$workspace", begin.WorkspaceFingerprint);
            command.Parameters.AddWithValue("$tool", begin.ToolName);
            command.Parameters.AddWithValue("$criterion", begin.CriterionId);
            command.Parameters.AddWithValue("$started", begin.StartedEpochMs);
            command.Parameters.AddWithValue("$backend", begin.BackendId);
            command.Parameters.AddWithValue("$backendMetadata", begin.BackendMetadataJson);
            command.Parameters.AddWithValue("$policyGeneration", begin.PolicyGeneration);
            command.Parameters.AddWithValue("$policyHash", begin.PolicyHash);
            command.Parameters.AddWithValue("$catalogHash", begin.CatalogHash);
            command.Parameters.AddWithValue("$catalogVersion", begin.CatalogVersion);
            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            await CheckpointAsync(connection, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _writeGate.Release();
        }
    }

    public async Task CompleteAsync(EvidenceCompletion completion, CancellationToken cancellationToken = default)
    {
        ValidateCompletion(completion);
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        var sourceBytes = completion.SourceStateJson is null ? 0 : Encoding.UTF8.GetByteCount(completion.SourceStateJson);
        if (sourceBytes > MaxSourceStateJsonBytes)
            throw new FileMcpException($"Evidence SourceStateRef metadata exceeds {MaxSourceStateJsonBytes} bytes");

        await _writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await EnsureStoreHasCapacityAsync(sourceBytes + 4096L, cancellationToken).ConfigureAwait(false);
            await using var connection = await OpenConfiguredConnectionAsync(cancellationToken).ConfigureAwait(false);
            await using var command = connection.CreateCommand();
            command.CommandText = """
                UPDATE evidence_records
                SET ended_epoch_ms=$ended,
                    operation_state=$operationState,
                    verification_state=$verificationState,
                    source_state_json=$sourceJson,
                    source_state_id=$sourceId,
                    project_context_digest=$contextDigest,
                    policy_generation=$policyGeneration,
                    policy_hash=$policyHash,
                    catalog_hash=$catalogHash,
                    catalog_version=$catalogVersion,
                    exit_code=$exitCode,
                    timed_out=$timedOut,
                    cancelled=$cancelled,
                    truncated=$truncated
                WHERE evidence_id=$evidence AND operation_state='running';
                """;
            command.Parameters.AddWithValue("$ended", completion.EndedEpochMs);
            command.Parameters.AddWithValue("$operationState", completion.OperationState);
            command.Parameters.AddWithValue("$verificationState", completion.VerificationState);
            command.Parameters.AddWithValue("$sourceJson", (object?)completion.SourceStateJson ?? DBNull.Value);
            command.Parameters.AddWithValue("$sourceId", (object?)completion.SourceStateId ?? DBNull.Value);
            command.Parameters.AddWithValue("$contextDigest", (object?)completion.ProjectContextDigest ?? DBNull.Value);
            command.Parameters.AddWithValue("$policyGeneration", completion.PolicyGeneration);
            command.Parameters.AddWithValue("$policyHash", completion.PolicyHash);
            command.Parameters.AddWithValue("$catalogHash", completion.CatalogHash);
            command.Parameters.AddWithValue("$catalogVersion", completion.CatalogVersion);
            command.Parameters.AddWithValue("$exitCode", (object?)completion.ExitCode ?? DBNull.Value);
            command.Parameters.AddWithValue("$timedOut", completion.TimedOut ? 1 : 0);
            command.Parameters.AddWithValue("$cancelled", completion.Cancelled ? 1 : 0);
            command.Parameters.AddWithValue("$truncated", completion.Truncated ? 1 : 0);
            command.Parameters.AddWithValue("$evidence", completion.EvidenceId);
            var changed = await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            if (changed != 1) throw new FileMcpException("Evidence terminal write failed because the running record is unavailable");
            await CleanupRetentionAndQuotaAsync(connection, reserveRecords: 0, cancellationToken).ConfigureAwait(false);
            await CheckpointAsync(connection, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _writeGate.Release();
        }
    }

    public async Task<EvidenceRecord?> GetAsync(string evidenceId, CancellationToken cancellationToken = default)
    {
        if (!IsEvidenceId(evidenceId)) throw new FileMcpException("Malformed evidence_id");
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await using var connection = await OpenConfiguredConnectionAsync(cancellationToken).ConfigureAwait(false);
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT evidence_id,operation_id,workspace_fingerprint,tool_name,criterion_id,
                   started_epoch_ms,ended_epoch_ms,operation_state,verification_state,backend_id,backend_metadata_json,
                   source_state_json,source_state_id,project_context_digest,
                   policy_generation,policy_hash,catalog_hash,catalog_version,
                   exit_code,timed_out,cancelled,truncated
            FROM evidence_records WHERE evidence_id=$evidence LIMIT 1;
            """;
        command.Parameters.AddWithValue("$evidence", evidenceId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
        if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false)) return null;
        return new EvidenceRecord(
            reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetString(3), reader.GetString(4),
            reader.GetInt64(5), reader.IsDBNull(6) ? null : reader.GetInt64(6), reader.GetString(7), reader.GetString(8), reader.GetString(9), reader.GetString(10),
            reader.IsDBNull(11) ? null : reader.GetString(11), reader.IsDBNull(12) ? null : reader.GetString(12), reader.IsDBNull(13) ? null : reader.GetString(13),
            reader.GetInt64(14), reader.GetString(15), reader.GetString(16), reader.GetString(17),
            reader.IsDBNull(18) ? null : reader.GetInt32(18), reader.GetInt64(19) != 0, reader.GetInt64(20) != 0, reader.GetInt64(21) != 0);
    }

    internal async Task<int> CountAsync(CancellationToken cancellationToken = default)
    {
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await using var connection = await OpenConfiguredConnectionAsync(cancellationToken).ConfigureAwait(false);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM evidence_records;";
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false));
    }

    private async Task CleanupRetentionAndQuotaAsync(SqliteConnection connection, int reserveRecords, CancellationToken cancellationToken)
    {
        var cutoff = _utcNow().Subtract(_retention).ToUnixTimeMilliseconds();
        await using (var retention = connection.CreateCommand())
        {
            retention.CommandText = "DELETE FROM evidence_records WHERE started_epoch_ms < $cutoff;";
            retention.Parameters.AddWithValue("$cutoff", cutoff);
            await retention.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        await using var count = connection.CreateCommand();
        count.CommandText = "SELECT COUNT(*) FROM evidence_records;";
        var existing = Convert.ToInt32(await count.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false));
        var allowedExisting = Math.Max(0, _maxRecords - reserveRecords);
        var excess = existing - allowedExisting;
        if (excess > 0)
        {
            await using var prune = connection.CreateCommand();
            prune.CommandText = """
                DELETE FROM evidence_records WHERE evidence_id IN (
                    SELECT evidence_id FROM evidence_records
                    WHERE operation_state <> 'running'
                    ORDER BY COALESCE(ended_epoch_ms,started_epoch_ms) ASC, evidence_id ASC
                    LIMIT $limit
                );
                """;
            prune.Parameters.AddWithValue("$limit", excess);
            await prune.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
            existing = Convert.ToInt32(await count.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false));
            if (existing > allowedExisting)
                throw new FileMcpException("Evidence record-count quota is exhausted by active records");
        }
    }

    private Task EnsureStoreHasCapacityAsync(long estimatedAdditionalBytes, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var current = DurableStoreBytes();
        if (current + Math.Max(estimatedAdditionalBytes, 0) <= _maxStoreBytes) return Task.CompletedTask;
        throw new FileMcpException("Evidence storage-size quota is exhausted");
    }

    private long DurableStoreBytes()
    {
        long total = 0;
        foreach (var path in new[] { _databasePath, _databasePath + "-wal" })
            if (File.Exists(path)) total = checked(total + new FileInfo(path).Length);
        return total;
    }

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

    private async Task ConfigurePageQuotaAsync(SqliteConnection connection, CancellationToken cancellationToken)
    {
        await using var pageSizeCommand = connection.CreateCommand();
        pageSizeCommand.CommandText = "PRAGMA page_size;";
        var pageSize = Convert.ToInt64(await pageSizeCommand.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false));
        var maxPages = Math.Max(16L, _maxStoreBytes / Math.Max(pageSize, 1));
        await ExecuteAsync(connection, $"PRAGMA max_page_count={maxPages};", cancellationToken).ConfigureAwait(false);
    }

    private static async Task CreateSchemaAsync(SqliteConnection connection, CancellationToken cancellationToken)
    {
        const string schema = """
            CREATE TABLE IF NOT EXISTS evidence_meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS evidence_records (
                evidence_id TEXT PRIMARY KEY,
                operation_id TEXT NOT NULL,
                workspace_fingerprint TEXT NOT NULL,
                tool_name TEXT NOT NULL,
                criterion_id TEXT NOT NULL,
                started_epoch_ms INTEGER NOT NULL,
                ended_epoch_ms INTEGER,
                operation_state TEXT NOT NULL,
                verification_state TEXT NOT NULL,
                backend_id TEXT NOT NULL,
                backend_metadata_json TEXT NOT NULL DEFAULT '{}',
                source_state_json TEXT,
                source_state_id TEXT,
                project_context_digest TEXT,
                policy_generation INTEGER NOT NULL,
                policy_hash TEXT NOT NULL,
                catalog_hash TEXT NOT NULL,
                catalog_version TEXT NOT NULL,
                exit_code INTEGER,
                timed_out INTEGER NOT NULL DEFAULT 0,
                cancelled INTEGER NOT NULL DEFAULT 0,
                truncated INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS ix_evidence_started ON evidence_records(started_epoch_ms);
            CREATE INDEX IF NOT EXISTS ix_evidence_workspace ON evidence_records(workspace_fingerprint,started_epoch_ms);
            """;
        await ExecuteAsync(connection, schema, cancellationToken).ConfigureAwait(false);
        await using var readVersion = connection.CreateCommand();
        readVersion.CommandText = "SELECT value FROM evidence_meta WHERE key='schema_version';";
        var existing = (string?)await readVersion.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);
        if (existing is null)
        {
            await using var insert = connection.CreateCommand();
            insert.CommandText = "INSERT INTO evidence_meta(key,value) VALUES('schema_version',$version);";
            insert.Parameters.AddWithValue("$version", SchemaVersion.ToString());
            await insert.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }
        else if (string.Equals(existing, "1", StringComparison.Ordinal))
        {
            await ExecuteAsync(connection, "ALTER TABLE evidence_records ADD COLUMN backend_metadata_json TEXT NOT NULL DEFAULT '{}';", cancellationToken).ConfigureAwait(false);
            await using var migrate = connection.CreateCommand();
            migrate.CommandText = "UPDATE evidence_meta SET value=$version WHERE key='schema_version';";
            migrate.Parameters.AddWithValue("$version", SchemaVersion.ToString());
            await migrate.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }
        else if (!string.Equals(existing, SchemaVersion.ToString(), StringComparison.Ordinal))
        {
            throw new FileMcpException($"Unsupported evidence database schema version: {existing}");
        }
    }

    private static async Task CheckpointAsync(SqliteConnection connection, CancellationToken cancellationToken) =>
        await ExecuteAsync(connection, "PRAGMA wal_checkpoint(TRUNCATE);", cancellationToken).ConfigureAwait(false);

    private static async Task ExecuteAsync(SqliteConnection connection, string sql, CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
    }

    private static void ValidateBegin(EvidenceBegin begin)
    {
        if (!IsEvidenceId(begin.EvidenceId)) throw new FileMcpException("Malformed evidence_id");
        if (!IsOperationId(begin.OperationId)) throw new FileMcpException("Malformed evidence operation_id");
        RequireBounded(begin.WorkspaceFingerprint, 128, nameof(begin.WorkspaceFingerprint));
        RequireBounded(begin.ToolName, 128, nameof(begin.ToolName));
        RequireBounded(begin.CriterionId, 128, nameof(begin.CriterionId));
        RequireBounded(begin.BackendId, 64, nameof(begin.BackendId));
        ValidateBackendMetadataJson(begin.BackendMetadataJson);
        RequireBounded(begin.PolicyHash, 128, nameof(begin.PolicyHash));
        RequireBounded(begin.CatalogHash, 128, nameof(begin.CatalogHash));
        RequireBounded(begin.CatalogVersion, 64, nameof(begin.CatalogVersion));
    }

    private static void ValidateCompletion(EvidenceCompletion completion)
    {
        if (!IsEvidenceId(completion.EvidenceId)) throw new FileMcpException("Malformed evidence_id");
        if (completion.OperationState is not ("succeeded" or "failed" or "timed_out" or "cancelled" or "unknown" or "blocked" or "not-run"))
            throw new FileMcpException("Unsupported evidence operation_state");
        if (completion.VerificationState is not ("passed" or "failed" or "not-run" or "unknown" or "stale" or "blocked" or "not-applicable"))
            throw new FileMcpException("Unsupported evidence verification_state");
        if (completion.SourceStateId is not null) RequireBounded(completion.SourceStateId, 128, nameof(completion.SourceStateId));
        if (completion.ProjectContextDigest is not null) RequireBounded(completion.ProjectContextDigest, 128, nameof(completion.ProjectContextDigest));
        RequireBounded(completion.PolicyHash, 128, nameof(completion.PolicyHash));
        RequireBounded(completion.CatalogHash, 128, nameof(completion.CatalogHash));
        RequireBounded(completion.CatalogVersion, 64, nameof(completion.CatalogVersion));
    }

    private static void ValidateBackendMetadataJson(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || Encoding.UTF8.GetByteCount(value) > MaxBackendMetadataJsonBytes)
            throw new FileMcpException("Invalid evidence backend metadata");
        try
        {
            using var document = JsonDocument.Parse(value);
            if (document.RootElement.ValueKind != JsonValueKind.Object)
                throw new FileMcpException("Evidence backend metadata must be a JSON object");
        }
        catch (JsonException)
        {
            throw new FileMcpException("Evidence backend metadata must be valid JSON");
        }
    }

    private static void RequireBounded(string value, int maxLength, string field)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > maxLength) throw new FileMcpException($"Invalid evidence metadata field: {field}");
    }

    private static bool IsEvidenceId(string value) =>
        value.Length == 35 && value.StartsWith("ev_", StringComparison.Ordinal) && value.AsSpan(3).ToString().All(Uri.IsHexDigit);

    private static bool IsOperationId(string value) =>
        value.Length == 35 && value.StartsWith("op_", StringComparison.Ordinal) && value.AsSpan(3).ToString().All(Uri.IsHexDigit);
}
