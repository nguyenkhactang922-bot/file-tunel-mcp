using System.Buffers;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Text.Json;

namespace FileMCP.Core;

internal static class ArtifactContentClasses
{
    public const string ToolOutput = "TOOL_OUTPUT";
    public const string PtyOutput = "PTY_OUTPUT";
    public const string Checkpoint = "CHECKPOINT";
    public const string Quarantine = "QUARANTINE";

    public static readonly IReadOnlySet<string> All = new HashSet<string>(
        [ToolOutput, PtyOutput, Checkpoint, Quarantine],
        StringComparer.Ordinal);

    public static bool IsKnown(string value) => All.Contains(value);
}

internal sealed class ArtifactContentStoreOptions
{
    public string? RootDirectory { get; init; }
    public string? WorkspaceRootForIsolation { get; init; }
    public long MaxItemBytes { get; init; } = 64L * 1024 * 1024;
    public long MaxWorkspaceBytes { get; init; } = 512L * 1024 * 1024;
    public long MaxGlobalBytes { get; init; } = 2L * 1024 * 1024 * 1024;
    public TimeSpan DefaultTtl { get; init; } = TimeSpan.FromHours(24);
    public TimeSpan MaxTtl { get; init; } = TimeSpan.FromDays(7);
    public Func<DateTimeOffset> UtcNow { get; init; } = () => DateTimeOffset.UtcNow;

    // Test-only deterministic fault injection. Production callers leave this null.
    internal Func<string, long, Exception?>? FaultInjector { get; init; }
}

internal sealed record ArtifactContentDescriptor(
    string ContentRef,
    string ReferenceId,
    string BlobId,
    long SizeBytes,
    string ContentClass,
    string MediaType,
    long CreatedEpochMs,
    long ExpiresEpochMs,
    string? LeaseId,
    long? LeaseExpiresEpochMs);

internal sealed record ArtifactStoreUsage(
    int ReferenceCount,
    int BlobCount,
    long GlobalBytes,
    long WorkspaceBytes);

internal sealed record ArtifactGcResult(
    int ExpiredReferencesRemoved,
    int OrphanBlobsRemoved,
    int StagingFilesRemoved);

internal sealed class ArtifactContentStore
{
    public const int SchemaVersion = 1;
    private const int BufferSize = 128 * 1024;
    private const int MaxTokenChars = 4096;
    private const int MaxBoundStringChars = 1024;

    private readonly ArtifactContentStoreOptions _options;
    private readonly string _rootDirectory;
    private readonly string _identityPath;
    private readonly string _indexPath;
    private readonly string _blobRoot;
    private readonly string _stagingRoot;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly JsonSerializerOptions _jsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
    };

    private bool _initialized;
    private StoreIdentity? _identity;
    private List<ReferenceRecord> _references = [];

    public ArtifactContentStore(ArtifactContentStoreOptions? options = null)
    {
        _options = options ?? new ArtifactContentStoreOptions();
        ValidateOptions(_options);

        _rootDirectory = Path.GetFullPath(_options.RootDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FileMCP",
            "artifacts-v1"));
        _identityPath = Path.Combine(_rootDirectory, "identity-v1.json");
        _indexPath = Path.Combine(_rootDirectory, "index-v1.json");
        _blobRoot = Path.Combine(_rootDirectory, "blobs");
        _stagingRoot = Path.Combine(_rootDirectory, "staging");

        if (!string.IsNullOrWhiteSpace(_options.WorkspaceRootForIsolation))
        {
            var workspace = Path.GetFullPath(_options.WorkspaceRootForIsolation);
            if (IsSameOrDescendant(_rootDirectory, workspace))
                throw new FileMcpException("Artifact root must be outside the workspace/repository");
        }
    }

    internal string RootDirectoryForTest => _rootDirectory;
    internal string IndexPathForTest => _indexPath;
    internal string IdentityPathForTest => _identityPath;

    public static string WorkspaceAuthorityId(string workspaceRoot)
    {
        var canonical = Path.GetFullPath(workspaceRoot).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (OperatingSystem.IsWindows()) canonical = canonical.ToUpperInvariant();
        return "sha256:" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
    }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        if (_initialized) return;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_initialized) return;

            HardenDirectory(_rootDirectory);
            HardenDirectory(_blobRoot);
            HardenDirectory(_stagingRoot);

            _identity = LoadOrCreateIdentity();
            _references = LoadSnapshot();
            await CleanupExpiredAndOrphansLockedAsync(cancellationToken).ConfigureAwait(false);
            _initialized = true;
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<ArtifactContentDescriptor> PutAsync(
        Stream source,
        string workspaceAuthorityId,
        string contentClass,
        string mediaType = "application/octet-stream",
        TimeSpan? ttl = null,
        string? leaseId = null,
        TimeSpan? leaseTtl = null,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(source);
        ValidateWorkspaceAuthority(workspaceAuthorityId);
        ValidateContentClass(contentClass);
        ValidateBoundString(mediaType, nameof(mediaType), 512);
        if (leaseId is not null) ValidateBoundString(leaseId, nameof(leaseId), 512);
        if (leaseId is null && leaseTtl is not null)
            throw new FileMcpException("Artifact lease TTL requires a lease id");

        var effectiveTtl = ttl ?? _options.DefaultTtl;
        if (effectiveTtl <= TimeSpan.Zero || effectiveTtl > _options.MaxTtl)
            throw new FileMcpException($"Artifact TTL must be positive and no more than {_options.MaxTtl.TotalHours:0.##} hours");
        if (leaseTtl is not null && (leaseTtl <= TimeSpan.Zero || leaseTtl > effectiveTtl))
            throw new FileMcpException("Artifact lease TTL must be positive and no longer than the ContentRef TTL");

        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);

        string? stagingPath = null;
        string? publishedBlobPath = null;
        bool publishedNewBlob = false;
        try
        {
            await CleanupExpiredAndOrphansLockedAsync(cancellationToken).ConfigureAwait(false);

            stagingPath = Path.Combine(_stagingRoot, "stage_" + Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant());
            var (blobId, sizeBytes) = await StageAndHashAsync(source, stagingPath, cancellationToken).ConfigureAwait(false);

            var blobHash = blobId["sha256:".Length..];
            var blobDirectory = Path.Combine(_blobRoot, blobHash[..2]);
            Directory.CreateDirectory(blobDirectory);
            publishedBlobPath = Path.Combine(blobDirectory, blobHash);

            var blobExists = File.Exists(publishedBlobPath);
            var globalBytes = ComputeGlobalBytes(_references);
            var workspaceBytes = ComputeWorkspaceBytes(_references, workspaceAuthorityId);
            var workspaceAlreadyReferencesBlob = _references.Any(r =>
                r.WorkspaceAuthorityId == workspaceAuthorityId &&
                r.BlobId == blobId &&
                r.ExpiresEpochMs > _options.UtcNow().ToUnixTimeMilliseconds());

            if (!blobExists && globalBytes + sizeBytes > _options.MaxGlobalBytes)
                throw new FileMcpException("Artifact global quota exhausted");
            if (!workspaceAlreadyReferencesBlob && workspaceBytes + sizeBytes > _options.MaxWorkspaceBytes)
                throw new FileMcpException("Artifact workspace quota exhausted");

            ThrowInjected("before-publish", sizeBytes);

            if (!blobExists)
            {
                File.Move(stagingPath, publishedBlobPath);
                stagingPath = null;
                publishedNewBlob = true;
            }
            else
            {
                File.Delete(stagingPath);
                stagingPath = null;
                await VerifyBlobIntegrityAsync(publishedBlobPath, blobId, sizeBytes, cancellationToken).ConfigureAwait(false);
            }

            var now = _options.UtcNow();
            var referenceId = "ref_" + Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant();
            var record = new ReferenceRecord
            {
                ReferenceId = referenceId,
                BlobId = blobId,
                SizeBytes = sizeBytes,
                WorkspaceAuthorityId = workspaceAuthorityId,
                ContentClass = contentClass,
                MediaType = mediaType,
                CreatedEpochMs = now.ToUnixTimeMilliseconds(),
                ExpiresEpochMs = now.Add(effectiveTtl).ToUnixTimeMilliseconds(),
                LeaseId = leaseId,
                LeaseExpiresEpochMs = leaseTtl is null ? null : now.Add(leaseTtl.Value).ToUnixTimeMilliseconds(),
            };
            var contentRef = EncodeContentRef(record);

            var candidate = _references.ToList();
            candidate.Add(record);
            ThrowInjected("before-index-commit", sizeBytes);
            PersistSnapshot(candidate);
            _references = candidate;

            return ToDescriptor(record, contentRef);
        }
        catch
        {
            if (publishedNewBlob && publishedBlobPath is not null)
            {
                try
                {
                    if (!_references.Any(r => PathForBlob(r.BlobId) == publishedBlobPath))
                        File.Delete(publishedBlobPath);
                }
                catch { }
            }
            throw;
        }
        finally
        {
            if (stagingPath is not null)
            {
                try { File.Delete(stagingPath); } catch { }
            }
            _gate.Release();
        }
    }

    public async Task<ArtifactContentDescriptor> ResolveAsync(
        string contentRef,
        string workspaceAuthorityId,
        Func<string, bool> contentClassAllowed,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(contentClassAllowed);
        ValidateWorkspaceAuthority(workspaceAuthorityId);
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var record = await ResolveRecordLockedAsync(contentRef, workspaceAuthorityId, contentClassAllowed, cancellationToken).ConfigureAwait(false);
            return ToDescriptor(record, contentRef);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task CopyToAsync(
        string contentRef,
        string workspaceAuthorityId,
        Func<string, bool> contentClassAllowed,
        Stream destination,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(destination);
        ArgumentNullException.ThrowIfNull(contentClassAllowed);
        ValidateWorkspaceAuthority(workspaceAuthorityId);

        await InitializeAsync(cancellationToken).ConfigureAwait(false);

        FileStream? input = null;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var record = await ResolveRecordLockedAsync(contentRef, workspaceAuthorityId, contentClassAllowed, cancellationToken).ConfigureAwait(false);
            input = new FileStream(
                PathForBlob(record.BlobId),
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read,
                BufferSize,
                FileOptions.Asynchronous | FileOptions.SequentialScan);
        }
        finally
        {
            _gate.Release();
        }

        await using (input.ConfigureAwait(false))
            await input.CopyToAsync(destination, BufferSize, cancellationToken).ConfigureAwait(false);
    }

    public async Task<bool> DeleteAsync(
        string contentRef,
        string workspaceAuthorityId,
        Func<string, bool> contentClassAllowed,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(contentClassAllowed);
        ValidateWorkspaceAuthority(workspaceAuthorityId);
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var record = await ResolveRecordLockedAsync(contentRef, workspaceAuthorityId, contentClassAllowed, cancellationToken).ConfigureAwait(false);
            var candidate = _references.Where(r => r.ReferenceId != record.ReferenceId).ToList();
            PersistSnapshot(candidate);
            _references = candidate;

            if (!_references.Any(r => r.BlobId == record.BlobId))
            {
                try { File.Delete(PathForBlob(record.BlobId)); } catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
            return true;
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<ArtifactGcResult> CollectGarbageAsync(CancellationToken cancellationToken = default)
    {
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            return await CleanupExpiredAndOrphansLockedAsync(cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<ArtifactStoreUsage> GetUsageAsync(
        string workspaceAuthorityId,
        CancellationToken cancellationToken = default)
    {
        ValidateWorkspaceAuthority(workspaceAuthorityId);
        await InitializeAsync(cancellationToken).ConfigureAwait(false);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var nowMs = _options.UtcNow().ToUnixTimeMilliseconds();
            var live = _references.Where(r => r.ExpiresEpochMs > nowMs).ToList();
            return new ArtifactStoreUsage(
                live.Count,
                live.Select(r => r.BlobId).Distinct(StringComparer.Ordinal).Count(),
                ComputeGlobalBytes(live),
                ComputeWorkspaceBytes(live, workspaceAuthorityId));
        }
        finally
        {
            _gate.Release();
        }
    }

    internal string BlobPathForTest(string blobId) => PathForBlob(blobId);

    internal bool HasCurrentUserOnlyPermissionsForTest()
    {
        if (!OperatingSystem.IsWindows()) return true;
        var sid = WindowsIdentity.GetCurrent().User;
        if (sid is null) return false;
        var security = FileSystemAclExtensions.GetAccessControl(new DirectoryInfo(_rootDirectory), AccessControlSections.Access);
        var rules = security.GetAccessRules(includeExplicit: true, includeInherited: true, targetType: typeof(SecurityIdentifier))
            .OfType<FileSystemAccessRule>()
            .Where(rule => rule.AccessControlType == AccessControlType.Allow)
            .ToList();
        return rules.Count > 0 && rules.All(rule => Equals(rule.IdentityReference, sid));
    }

    private async Task<ReferenceRecord> ResolveRecordLockedAsync(
        string contentRef,
        string workspaceAuthorityId,
        Func<string, bool> contentClassAllowed,
        CancellationToken cancellationToken)
    {
        var payload = DecodeContentRef(contentRef);
        var identity = RequireIdentity();

        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(payload.InstallationId),
                Encoding.UTF8.GetBytes(identity.InstallationId)))
            throw new FileMcpException("ContentRef installation mismatch");
        if (!string.Equals(payload.WorkspaceAuthorityId, workspaceAuthorityId, StringComparison.Ordinal))
            throw new FileMcpException("ContentRef workspace mismatch");
        if (!ArtifactContentClasses.IsKnown(payload.ContentClass) || !contentClassAllowed(payload.ContentClass))
            throw new FileMcpException("ContentRef content class denied by current policy");

        var nowMs = _options.UtcNow().ToUnixTimeMilliseconds();
        if (payload.ExpiresEpochMs <= nowMs)
            throw new FileMcpException("ContentRef expired");
        if (payload.LeaseExpiresEpochMs is not null && payload.LeaseExpiresEpochMs <= nowMs)
            throw new FileMcpException("ContentRef lease expired");

        var record = _references.SingleOrDefault(r => r.ReferenceId == payload.ReferenceId)
            ?? throw new FileMcpException("ContentRef unavailable");
        if (record.BlobId != payload.BlobId ||
            record.WorkspaceAuthorityId != payload.WorkspaceAuthorityId ||
            record.ContentClass != payload.ContentClass ||
            record.ExpiresEpochMs != payload.ExpiresEpochMs ||
            record.LeaseId != payload.LeaseId ||
            record.LeaseExpiresEpochMs != payload.LeaseExpiresEpochMs)
            throw new FileMcpException("ContentRef metadata mismatch");

        var blobPath = PathForBlob(record.BlobId);
        if (!File.Exists(blobPath))
            throw new FileMcpException("ContentRef blob unavailable");
        await VerifyBlobIntegrityAsync(blobPath, record.BlobId, record.SizeBytes, cancellationToken).ConfigureAwait(false);
        return record;
    }

    private async Task<(string BlobId, long SizeBytes)> StageAndHashAsync(
        Stream source,
        string stagingPath,
        CancellationToken cancellationToken)
    {
        long size = 0;
        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        var buffer = ArrayPool<byte>.Shared.Rent(BufferSize);
        try
        {
            await using var output = new FileStream(
                stagingPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                BufferSize,
                FileOptions.Asynchronous | FileOptions.SequentialScan | FileOptions.WriteThrough);
            while (true)
            {
                var read = await source.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken).ConfigureAwait(false);
                if (read == 0) break;
                size = checked(size + read);
                if (size > _options.MaxItemBytes)
                    throw new FileMcpException("Artifact per-item quota exhausted");
                hash.AppendData(buffer, 0, read);
                await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
            }
            await output.FlushAsync(cancellationToken).ConfigureAwait(false);
            output.Flush(flushToDisk: true);
        }
        catch
        {
            try { File.Delete(stagingPath); } catch { }
            throw;
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer, clearArray: true);
        }

        var digest = Convert.ToHexString(hash.GetHashAndReset()).ToLowerInvariant();
        return ("sha256:" + digest, size);
    }

    private async Task VerifyBlobIntegrityAsync(
        string path,
        string expectedBlobId,
        long expectedSize,
        CancellationToken cancellationToken)
    {
        var info = new FileInfo(path);
        if (!info.Exists || info.Length != expectedSize)
            throw new FileMcpException("Artifact blob is corrupt: size mismatch");

        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        var buffer = ArrayPool<byte>.Shared.Rent(BufferSize);
        try
        {
            await using var stream = new FileStream(
                path,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read,
                BufferSize,
                FileOptions.Asynchronous | FileOptions.SequentialScan);
            while (true)
            {
                var read = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken).ConfigureAwait(false);
                if (read == 0) break;
                hash.AppendData(buffer, 0, read);
            }
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer, clearArray: true);
        }

        var actual = "sha256:" + Convert.ToHexString(hash.GetHashAndReset()).ToLowerInvariant();
        if (!string.Equals(actual, expectedBlobId, StringComparison.Ordinal))
            throw new FileMcpException("Artifact blob is corrupt: digest mismatch");
    }

    private async Task<ArtifactGcResult> CleanupExpiredAndOrphansLockedAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var nowMs = _options.UtcNow().ToUnixTimeMilliseconds();
        var live = _references.Where(r => r.ExpiresEpochMs > nowMs).ToList();
        var expiredRemoved = _references.Count - live.Count;
        if (expiredRemoved > 0)
        {
            PersistSnapshot(live);
            _references = live;
        }

        var referenced = _references.Select(r => r.BlobId["sha256:".Length..]).ToHashSet(StringComparer.Ordinal);
        var orphanRemoved = 0;
        if (Directory.Exists(_blobRoot))
        {
            foreach (var file in Directory.EnumerateFiles(_blobRoot, "*", SearchOption.AllDirectories))
            {
                cancellationToken.ThrowIfCancellationRequested();
                if (!referenced.Contains(Path.GetFileName(file)))
                {
                    try
                    {
                        File.Delete(file);
                        orphanRemoved++;
                    }
                    catch (IOException) { }
                    catch (UnauthorizedAccessException) { }
                }
            }
        }

        var stagingRemoved = 0;
        if (Directory.Exists(_stagingRoot))
        {
            foreach (var file in Directory.EnumerateFiles(_stagingRoot))
            {
                cancellationToken.ThrowIfCancellationRequested();
                try
                {
                    File.Delete(file);
                    stagingRemoved++;
                }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }

        await Task.CompletedTask.ConfigureAwait(false);
        return new ArtifactGcResult(expiredRemoved, orphanRemoved, stagingRemoved);
    }

    private StoreIdentity LoadOrCreateIdentity()
    {
        if (File.Exists(_identityPath))
        {
            var identity = JsonSerializer.Deserialize<StoreIdentity>(File.ReadAllBytes(_identityPath), _jsonOptions)
                ?? throw new FileMcpException("Artifact store identity is unavailable");
            ValidateIdentity(identity);
            return identity;
        }

        var created = new StoreIdentity
        {
            SchemaVersion = SchemaVersion,
            InstallationId = "inst_" + Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant(),
            AuthenticationKey = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)),
        };
        WriteAtomicBytes(_identityPath, JsonSerializer.SerializeToUtf8Bytes(created, _jsonOptions), overwrite: false);
        return created;
    }

    private List<ReferenceRecord> LoadSnapshot()
    {
        if (!File.Exists(_indexPath)) return [];
        try
        {
            var snapshot = JsonSerializer.Deserialize<StoreSnapshot>(File.ReadAllBytes(_indexPath), _jsonOptions)
                ?? throw new FileMcpException("Artifact metadata index is unavailable");
            if (snapshot.SchemaVersion != SchemaVersion)
                throw new FileMcpException("Unsupported artifact metadata schema version");
            foreach (var record in snapshot.References) ValidateRecord(record);
            return snapshot.References;
        }
        catch (JsonException ex)
        {
            throw new FileMcpException($"Artifact metadata index is corrupt: {ex.Message}");
        }
    }

    private void PersistSnapshot(List<ReferenceRecord> references)
    {
        var snapshot = new StoreSnapshot { SchemaVersion = SchemaVersion, References = references };
        var data = JsonSerializer.SerializeToUtf8Bytes(snapshot, _jsonOptions);
        WriteAtomicBytes(_indexPath, data, overwrite: true);
    }

    private string EncodeContentRef(ReferenceRecord record)
    {
        var identity = RequireIdentity();
        var payloadText = string.Join("|",
            "1",
            identity.InstallationId,
            record.WorkspaceAuthorityId,
            record.BlobId,
            record.ContentClass,
            record.ExpiresEpochMs.ToString(System.Globalization.CultureInfo.InvariantCulture),
            record.ReferenceId,
            record.LeaseId ?? "-",
            (record.LeaseExpiresEpochMs ?? 0L).ToString(System.Globalization.CultureInfo.InvariantCulture));
        var payload = Encoding.UTF8.GetBytes(payloadText);
        var signature = HMACSHA256.HashData(identity.KeyBytes, payload);
        return "cr1." + Base64Url(payload) + "." + Base64Url(signature);
    }

    private ContentRefPayload DecodeContentRef(string contentRef)
    {
        if (string.IsNullOrWhiteSpace(contentRef) || contentRef.Length > MaxTokenChars)
            throw new FileMcpException("Malformed ContentRef");
        var parts = contentRef.Split('.', StringSplitOptions.None);
        if (parts.Length != 3 || parts[0] != "cr1")
            throw new FileMcpException("Malformed ContentRef");

        byte[] payload;
        byte[] signature;
        try
        {
            payload = FromBase64Url(parts[1]);
            signature = FromBase64Url(parts[2]);
        }
        catch (FormatException)
        {
            throw new FileMcpException("Malformed ContentRef");
        }
        if (payload.Length == 0 || payload.Length > 3072 || signature.Length != 32)
            throw new FileMcpException("Malformed ContentRef");

        var identity = RequireIdentity();
        var expected = HMACSHA256.HashData(identity.KeyBytes, payload);
        if (!CryptographicOperations.FixedTimeEquals(expected, signature))
            throw new FileMcpException("ContentRef authentication failed");

        var fields = Encoding.UTF8.GetString(payload).Split('|', StringSplitOptions.None);
        if (fields.Length != 9 || fields[0] != "1" ||
            !long.TryParse(fields[5], System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out var expiry) ||
            !long.TryParse(fields[8], System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out var leaseExpiryRaw))
            throw new FileMcpException("Malformed ContentRef payload");

        ValidateBoundString(fields[1], "installationId", 128);
        ValidateWorkspaceAuthority(fields[2]);
        ValidateBlobId(fields[3]);
        ValidateContentClass(fields[4]);
        ValidateBoundString(fields[6], "referenceId", 128);
        var leaseId = fields[7] == "-" ? null : fields[7];
        if (leaseId is not null) ValidateBoundString(leaseId, "leaseId", 512);
        long? leaseExpiry = leaseExpiryRaw == 0 ? null : leaseExpiryRaw;
        if ((leaseId is null) != (leaseExpiry is null))
            throw new FileMcpException("Malformed ContentRef lease payload");

        return new ContentRefPayload(fields[1], fields[2], fields[3], fields[4], expiry, fields[6], leaseId, leaseExpiry);
    }

    private string PathForBlob(string blobId)
    {
        ValidateBlobId(blobId);
        var hash = blobId["sha256:".Length..];
        return Path.Combine(_blobRoot, hash[..2], hash);
    }

    private long ComputeGlobalBytes(IEnumerable<ReferenceRecord> references) =>
        references
            .GroupBy(r => r.BlobId, StringComparer.Ordinal)
            .Sum(group => group.First().SizeBytes);

    private long ComputeWorkspaceBytes(IEnumerable<ReferenceRecord> references, string workspaceAuthorityId) =>
        references
            .Where(r => r.WorkspaceAuthorityId == workspaceAuthorityId)
            .GroupBy(r => r.BlobId, StringComparer.Ordinal)
            .Sum(group => group.First().SizeBytes);

    private ArtifactContentDescriptor ToDescriptor(ReferenceRecord record, string contentRef) =>
        new(
            contentRef,
            record.ReferenceId,
            record.BlobId,
            record.SizeBytes,
            record.ContentClass,
            record.MediaType,
            record.CreatedEpochMs,
            record.ExpiresEpochMs,
            record.LeaseId,
            record.LeaseExpiresEpochMs);

    private StoreIdentity RequireIdentity() =>
        _identity ?? throw new FileMcpException("Artifact store is not initialized");

    private void ThrowInjected(string stage, long sizeBytes)
    {
        var failure = _options.FaultInjector?.Invoke(stage, sizeBytes);
        if (failure is not null) throw failure;
    }

    private static void ValidateOptions(ArtifactContentStoreOptions options)
    {
        if (options.MaxItemBytes < 1) throw new ArgumentOutOfRangeException(nameof(options.MaxItemBytes));
        if (options.MaxWorkspaceBytes < options.MaxItemBytes) throw new ArgumentOutOfRangeException(nameof(options.MaxWorkspaceBytes));
        if (options.MaxGlobalBytes < options.MaxWorkspaceBytes) throw new ArgumentOutOfRangeException(nameof(options.MaxGlobalBytes));
        if (options.DefaultTtl <= TimeSpan.Zero || options.MaxTtl <= TimeSpan.Zero || options.DefaultTtl > options.MaxTtl)
            throw new ArgumentOutOfRangeException(nameof(options.DefaultTtl));
        if (options.MaxTtl > TimeSpan.FromDays(30))
            throw new ArgumentOutOfRangeException(nameof(options.MaxTtl), "Artifact max TTL must not exceed 30 days");
        ArgumentNullException.ThrowIfNull(options.UtcNow);
    }

    private static void ValidateIdentity(StoreIdentity identity)
    {
        if (identity.SchemaVersion != SchemaVersion)
            throw new FileMcpException("Unsupported artifact identity schema version");
        ValidateBoundString(identity.InstallationId, "installationId", 128);
        try
        {
            if (Convert.FromBase64String(identity.AuthenticationKey).Length != 32)
                throw new FileMcpException("Artifact authentication key must be 32 bytes");
        }
        catch (FormatException)
        {
            throw new FileMcpException("Artifact authentication key is malformed");
        }
    }

    private static void ValidateRecord(ReferenceRecord record)
    {
        ValidateBoundString(record.ReferenceId, "referenceId", 128);
        ValidateBlobId(record.BlobId);
        ValidateWorkspaceAuthority(record.WorkspaceAuthorityId);
        ValidateContentClass(record.ContentClass);
        ValidateBoundString(record.MediaType, "mediaType", 512);
        if (record.SizeBytes < 0 || record.CreatedEpochMs < 0 || record.ExpiresEpochMs <= record.CreatedEpochMs)
            throw new FileMcpException("Artifact metadata record is invalid");
        if (record.LeaseId is not null) ValidateBoundString(record.LeaseId, "leaseId", 512);
        if ((record.LeaseId is null) != (record.LeaseExpiresEpochMs is null))
            throw new FileMcpException("Artifact lease metadata is invalid");
        if (record.LeaseExpiresEpochMs is not null &&
            (record.LeaseExpiresEpochMs <= record.CreatedEpochMs || record.LeaseExpiresEpochMs > record.ExpiresEpochMs))
            throw new FileMcpException("Artifact lease expiry is invalid");
    }

    private static void ValidateWorkspaceAuthority(string value)
    {
        ValidateBoundString(value, "workspaceAuthorityId", 256);
        if (!value.StartsWith("sha256:", StringComparison.Ordinal) ||
            value.Length != "sha256:".Length + 64 ||
            !value["sha256:".Length..].All(Uri.IsHexDigit))
            throw new FileMcpException("Malformed workspace authority id");
    }

    private static void ValidateBlobId(string value)
    {
        if (!value.StartsWith("sha256:", StringComparison.Ordinal) ||
            value.Length != "sha256:".Length + 64 ||
            !value["sha256:".Length..].All(Uri.IsHexDigit))
            throw new FileMcpException("Malformed artifact blob id");
    }

    private static void ValidateContentClass(string value)
    {
        if (!ArtifactContentClasses.IsKnown(value))
            throw new FileMcpException("Unsupported artifact content class");
    }

    private static void ValidateBoundString(string value, string name, int maxChars)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > Math.Min(maxChars, MaxBoundStringChars) || value.Contains('|'))
            throw new FileMcpException($"{name} must be a non-empty bounded string without reserved separators");
    }

    private static void HardenDirectory(string path)
    {
        Directory.CreateDirectory(path);
        if (!OperatingSystem.IsWindows()) return;

        var sid = WindowsIdentity.GetCurrent().User
            ?? throw new FileMcpException("Could not determine the current Windows user SID for artifact storage");
        var security = new DirectorySecurity();
        security.SetOwner(sid);
        security.SetAccessRuleProtection(isProtected: true, preserveInheritance: false);
        security.AddAccessRule(new FileSystemAccessRule(
            sid,
            FileSystemRights.FullControl,
            InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit,
            PropagationFlags.None,
            AccessControlType.Allow));
        FileSystemAclExtensions.SetAccessControl(new DirectoryInfo(path), security);
    }

    private static bool IsSameOrDescendant(string candidate, string root)
    {
        var comparison = OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
        var normalizedCandidate = Path.GetFullPath(candidate).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var normalizedRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        return normalizedCandidate.Equals(normalizedRoot, comparison) ||
            normalizedCandidate.StartsWith(normalizedRoot + Path.DirectorySeparatorChar, comparison);
    }

    private static void WriteAtomicBytes(string path, byte[] data, bool overwrite)
    {
        var directory = Path.GetDirectoryName(path) ?? throw new FileMcpException("Artifact metadata path has no parent directory");
        Directory.CreateDirectory(directory);
        var temp = Path.Combine(directory, ".tmp_" + Convert.ToHexString(RandomNumberGenerator.GetBytes(12)).ToLowerInvariant());
        try
        {
            using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None, 64 * 1024, FileOptions.WriteThrough))
            {
                stream.Write(data, 0, data.Length);
                stream.Flush(flushToDisk: true);
            }
            File.Move(temp, path, overwrite);
        }
        finally
        {
            try { File.Delete(temp); } catch { }
        }
    }

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] FromBase64Url(string value)
    {
        if (string.IsNullOrWhiteSpace(value)) throw new FormatException();
        var normalized = value.Replace('-', '+').Replace('_', '/');
        normalized += new string('=', (4 - normalized.Length % 4) % 4);
        return Convert.FromBase64String(normalized);
    }

    private sealed class StoreIdentity
    {
        public int SchemaVersion { get; set; }
        public string InstallationId { get; set; } = "";
        public string AuthenticationKey { get; set; } = "";

        public byte[] KeyBytes => Convert.FromBase64String(AuthenticationKey);
    }

    private sealed class StoreSnapshot
    {
        public int SchemaVersion { get; set; }
        public List<ReferenceRecord> References { get; set; } = [];
    }

    private sealed class ReferenceRecord
    {
        public string ReferenceId { get; set; } = "";
        public string BlobId { get; set; } = "";
        public long SizeBytes { get; set; }
        public string WorkspaceAuthorityId { get; set; } = "";
        public string ContentClass { get; set; } = "";
        public string MediaType { get; set; } = "";
        public long CreatedEpochMs { get; set; }
        public long ExpiresEpochMs { get; set; }
        public string? LeaseId { get; set; }
        public long? LeaseExpiresEpochMs { get; set; }
    }

    private sealed record ContentRefPayload(
        string InstallationId,
        string WorkspaceAuthorityId,
        string BlobId,
        string ContentClass,
        long ExpiresEpochMs,
        string ReferenceId,
        string? LeaseId,
        long? LeaseExpiresEpochMs);
}
