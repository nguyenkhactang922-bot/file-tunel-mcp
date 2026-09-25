using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace FileMCP.Core;

internal sealed partial class LocalTools
{
    internal const string SourceStateProviderVersion = "source-state-v1";
    private const int MaxSourceStatePaths = 4096;
    private const long MaxSourceStateHashedBytes = 50_000_000;

    internal async Task<JsonObject> CaptureSourceStateRefAsync(
        string repoPath,
        IReadOnlyList<string>? relevantPaths = null,
        CancellationToken cancellationToken = default)
    {
        var repo = await GitRepoAsync(repoPath, cancellationToken).ConfigureAwait(false);
        var scopes = NormalizeSourceStateScopes(repo, relevantPaths);
        var narrow = scopes.Count > 0;
        var repoRelative = _resolver.RelativePath(repo);
        var pathspecSuffix = narrow ? new[] { "--" }.Concat(scopes).ToArray() : Array.Empty<string>();

        string? headOid = null;
        string headScopeFingerprint;
        try
        {
            var rawHead = await RunGitAsync(repo, ["rev-parse", "--verify", "HEAD"], FileMcpConstants.MaxGitSafetyOutputBytes, cancellationToken: cancellationToken).ConfigureAwait(false);
            headOid = rawHead.Trim();
            if (headOid.Length is < 7 or > 128 || !headOid.All(Uri.IsHexDigit))
                throw new FileMcpException("Could not validate Git HEAD identity for SourceStateRef");
            if (narrow)
            {
                var headScope = await RunGitAsync(repo, ["ls-tree", "-r", "-z", "HEAD", .. pathspecSuffix], FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false);
                EnsureCompleteGitSafetyOutput(headScope, "SourceStateRef HEAD scope");
                headScopeFingerprint = FileVersionService.Sha256Tagged(headScope);
            }
            else
            {
                headScopeFingerprint = FileVersionService.Sha256Tagged(headOid);
            }
        }
        catch (FileMcpException ex) when (ex.Message.Contains("needed a single revision", StringComparison.OrdinalIgnoreCase) ||
                                           ex.Message.Contains("unknown revision", StringComparison.OrdinalIgnoreCase) ||
                                           ex.Message.Contains("ambiguous argument", StringComparison.OrdinalIgnoreCase))
        {
            headOid = null;
            headScopeFingerprint = FileVersionService.Sha256Tagged("unborn");
        }

        var indexArgs = new List<string> { "ls-files", "-s", "-z" };
        if (narrow) indexArgs.AddRange(pathspecSuffix);
        var indexRaw = await RunGitAsync(repo, indexArgs, FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false);
        EnsureCompleteGitSafetyOutput(indexRaw, "SourceStateRef index scan");

        var trackedArgs = new List<string> { "diff", "--name-only", "-z" };
        if (headOid is not null) trackedArgs.Add("HEAD");
        trackedArgs.Add("--");
        if (narrow) trackedArgs.AddRange(scopes);
        var trackedRaw = await RunGitAsync(repo, trackedArgs, FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false);
        EnsureCompleteGitSafetyOutput(trackedRaw, "SourceStateRef tracked scan");

        var untrackedArgs = new List<string> { "ls-files", "--others", "--exclude-standard", "-z", "--" };
        if (narrow) untrackedArgs.AddRange(scopes);
        var untrackedRaw = await RunGitAsync(repo, untrackedArgs, FileMcpConstants.MaxGitSafetyOutputBytes, false, cancellationToken).ConfigureAwait(false);
        EnsureCompleteGitSafetyOutput(untrackedRaw, "SourceStateRef untracked scan");

        long hashedBytes = 0;
        var trackedFingerprint = HashSourceStatePaths(repoRelative, SplitNulPaths(trackedRaw), ref hashedBytes);
        var untrackedFingerprint = HashSourceStatePaths(repoRelative, SplitNulPaths(untrackedRaw), ref hashedBytes);
        var fileVersions = narrow ? CaptureScopedFileVersions(repoRelative, scopes) : new JsonArray();
        var policy = _policy.Capture();
        var worktreeFingerprint = FileVersionService.Sha256Tagged(Path.GetFullPath(repo).ToUpperInvariant());
        var scopeFingerprint = narrow
            ? FileVersionService.Sha256Tagged(string.Join("\n", scopes))
            : FileVersionService.Sha256Tagged("repository");

        var state = new JsonObject
        {
            ["provider_version"] = SourceStateProviderVersion,
            ["scope"] = narrow ? "relevant_files" : "repository",
            ["scope_fingerprint"] = scopeFingerprint,
            ["worktree_fingerprint"] = worktreeFingerprint,
            ["head_oid"] = narrow ? null : headOid,
            ["head_scope_fingerprint"] = headScopeFingerprint,
            ["index_fingerprint"] = FileVersionService.Sha256Tagged(indexRaw),
            ["tracked_dirty_fingerprint"] = trackedFingerprint,
            ["untracked_fingerprint"] = untrackedFingerprint,
            ["catalog_hash"] = CanonicalToolCatalog.CatalogHash,
            ["policy_generation"] = policy.Generation,
            ["policy_hash"] = policy.Hash,
            ["file_versions"] = fileVersions,
        };
        state["source_state_id"] = ComputeSourceStateId(state);
        return state;
    }

    private IReadOnlyList<string> NormalizeSourceStateScopes(string repo, IReadOnlyList<string>? relevantPaths)
    {
        if (relevantPaths is null || relevantPaths.Count == 0) return [];
        if (relevantPaths.Count > MaxSourceStatePaths) throw new FileMcpException($"SourceStateRef supports at most {MaxSourceStatePaths} relevant paths");
        var repoFull = Path.GetFullPath(repo).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var repoPrefix = repoFull + Path.DirectorySeparatorChar;
        var normalized = new SortedSet<string>(StringComparer.Ordinal);
        foreach (var raw in relevantPaths)
        {
            if (string.IsNullOrWhiteSpace(raw) || Path.IsPathRooted(raw)) throw new FileMcpException("SourceStateRef relevant paths must be relative repository paths");
            var candidate = Path.GetFullPath(Path.Combine(repoFull, raw));
            if (!candidate.StartsWith(repoPrefix, StringComparison.OrdinalIgnoreCase) && !string.Equals(candidate, repoFull, StringComparison.OrdinalIgnoreCase))
                throw new FileMcpException("SourceStateRef relevant path is outside the repository");
            var repoRelative = Path.GetRelativePath(repoFull, candidate).Replace('\\', '/');
            if (repoRelative is "." or "" || repoRelative.StartsWith("../", StringComparison.Ordinal))
                throw new FileMcpException("SourceStateRef relevant path must identify a repository entry");
            var sharedRelative = _resolver.RelativePath(candidate);
            _ = _resolver.Resolve(sharedRelative);
            normalized.Add(repoRelative);
        }
        return normalized.ToArray();
    }

    private string HashSourceStatePaths(string repoRelative, IReadOnlyList<string> paths, ref long hashedBytes)
    {
        using var aggregate = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        foreach (var path in paths.OrderBy(value => value, StringComparer.Ordinal))
        {
            var normalized = path.Replace('\\', '/');
            var pathFingerprint = FileVersionService.Sha256Tagged(normalized);
            var sharedRelative = string.IsNullOrEmpty(repoRelative) ? normalized : repoRelative.TrimEnd('/') + "/" + normalized;
            string state;
            try
            {
                var target = _resolver.Resolve(sharedRelative);
                if (File.Exists(target))
                {
                    var info = new FileInfo(target);
                    if (info.Length > MaxSourceStateHashedBytes - hashedBytes)
                        throw new FileMcpException("SourceStateRef file hashing exceeded the 50 MB aggregate limit");
                    hashedBytes += info.Length;
                    using var stream = new FileStream(target, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 64 * 1024, FileOptions.SequentialScan);
                    state = "file:" + "sha256:" + Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
                }
                else if (Directory.Exists(target)) state = "directory";
                else state = "missing";
            }
            catch (FileNotFoundException) { state = "missing"; }
            catch (DirectoryNotFoundException) { state = "missing"; }
            AppendUtf8(aggregate, pathFingerprint + "\0" + state + "\0");
        }
        return "sha256:" + Convert.ToHexString(aggregate.GetHashAndReset()).ToLowerInvariant();
    }

    private JsonArray CaptureScopedFileVersions(string repoRelative, IReadOnlyList<string> scopes)
    {
        var result = new JsonArray();
        foreach (var scope in scopes)
        {
            var sharedRelative = string.IsNullOrEmpty(repoRelative) ? scope : repoRelative.TrimEnd('/') + "/" + scope;
            var pathFingerprint = FileVersionService.Sha256Tagged(scope);
            var item = new JsonObject { ["path_fingerprint"] = pathFingerprint };
            try
            {
                var target = _resolver.Resolve(sharedRelative);
                if (File.Exists(target))
                {
                    var info = new FileInfo(target);
                    item["size_bytes"] = info.Length;
                    if (info.Length <= FileMcpConstants.MaxFileBytes)
                    {
                        var versioned = _fileVersions.ReadVersioned(sharedRelative, FileMcpConstants.MaxFileBytes);
                        item["state"] = "file";
                        item["version_ref"] = versioned.VersionFingerprint;
                    }
                    else
                    {
                        item["state"] = "file_large";
                    }
                }
                else if (Directory.Exists(target))
                {
                    item["state"] = "directory";
                }
                else item["state"] = "missing";
            }
            catch (FileNotFoundException) { item["state"] = "missing"; }
            catch (DirectoryNotFoundException) { item["state"] = "missing"; }
            result.Add(item);
        }
        return result;
    }

    private static IReadOnlyList<string> SplitNulPaths(string value) =>
        value.Split('\0', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(path => path.Replace('\\', '/'))
            .Distinct(StringComparer.Ordinal)
            .ToArray();

    private static string ComputeSourceStateId(JsonObject state)
    {
        var clone = state.DeepClone().AsObject();
        clone.Remove("source_state_id");
        return FileVersionService.Sha256Tagged(clone.ToJsonString());
    }

    private static void AppendUtf8(IncrementalHash hash, string value) => hash.AppendData(Encoding.UTF8.GetBytes(value));
}
