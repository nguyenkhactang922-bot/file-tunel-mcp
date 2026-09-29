using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace FileMCP.Core;

internal sealed record RepositoryIntelligenceSymbol(
    string Name,
    string Kind,
    string File,
    int Line);

internal sealed record RepositoryIntelligenceFile(
    string Path,
    string Language,
    long SizeBytes,
    IReadOnlyList<RepositoryIntelligenceSymbol> Symbols,
    IReadOnlyList<string> Imports);

internal sealed record RepositoryIntelligenceRelation(
    string Source,
    string Target,
    string Reason,
    double Score);

internal sealed record RepositoryIntelligenceSnapshot(
    string ProviderId,
    string ProviderVersion,
    string Completeness,
    string SourceStateId,
    string GenerationId,
    long BuiltEpochMs,
    IReadOnlyList<RepositoryIntelligenceFile> Files,
    IReadOnlyList<RepositoryIntelligenceRelation> Relations,
    bool CacheHit)
{
    public JsonObject Metadata() => new()
    {
        ["provider_id"] = ProviderId,
        ["provider_version"] = ProviderVersion,
        ["completeness"] = Completeness,
        ["source_state_id"] = SourceStateId,
        ["generation_id"] = GenerationId,
        ["built_epoch_ms"] = BuiltEpochMs,
        ["file_count"] = Files.Count,
        ["relation_count"] = Relations.Count,
        ["cache_hit"] = CacheHit,
    };
}

internal sealed record RepositoryIntelligenceBuildContext(
    IReadOnlyList<(string RelativePath, string AbsolutePath, long SizeBytes)> Files,
    CancellationToken CancellationToken);

internal sealed record RepositoryIntelligenceProviderResult(
    IReadOnlyList<RepositoryIntelligenceFile> Files,
    IReadOnlyList<RepositoryIntelligenceRelation> Relations);

internal interface IRepositoryIntelligenceProvider
{
    string ProviderId { get; }
    string ProviderVersion { get; }
    string Completeness { get; }
    Task<RepositoryIntelligenceProviderResult> BuildAsync(RepositoryIntelligenceBuildContext context);
}

internal sealed class LexicalSymbolProvider : IRepositoryIntelligenceProvider
{
    public const string Id = "lexical";
    public const string Version = "lexical-v1";
    public const string HeuristicCompleteness = "heuristic";

    private const int MaxFileBytes = 512 * 1024;
    private const long MaxAggregateBytes = 20L * 1024 * 1024;

    private static readonly Regex CSharpSymbol = new(
        @"^\s*(?:(?:public|internal|private|protected|static|sealed|abstract|partial|async|virtual|override|readonly)\s+)*(?<kind>class|interface|record|struct|enum|namespace)\s+(?<name>[A-Za-z_][A-Za-z0-9_.]*)",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private static readonly Regex CSharpMethod = new(
        @"^\s*(?:(?:public|internal|private|protected|static|async|virtual|override|sealed|partial|extern|unsafe)\s+)+[A-Za-z_][A-Za-z0-9_<>,?\[\].\s]*\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*\(",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private static readonly Regex SwiftSymbol = new(
        @"^\s*(?:(?:public|internal|private|fileprivate|open|final|static|class|actor|nonisolated|@\w+)\s+)*(?<kind>class|struct|enum|protocol|actor|func)\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private static readonly Regex PythonSymbol = new(
        @"^\s*(?<kind>class|def|async\s+def)\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private static readonly Regex JsSymbol = new(
        @"^\s*(?:(?:export|default|async|declare)\s+)*(?<kind>class|function|interface|type|enum)\s+(?<name>[A-Za-z_$][A-Za-z0-9_$]*)",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);
    private static readonly Regex JsConstSymbol = new(
        @"^\s*(?:(?:export|default)\s+)?(?:const|let|var)\s+(?<name>[A-Za-z_$][A-Za-z0-9_$]*)\s*=",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    public string ProviderId => Id;
    public string ProviderVersion => Version;
    public string Completeness => HeuristicCompleteness;

    public Task<RepositoryIntelligenceProviderResult> BuildAsync(RepositoryIntelligenceBuildContext context)
    {
        var files = new List<RepositoryIntelligenceFile>();
        long aggregate = 0;
        foreach (var entry in context.Files)
        {
            context.CancellationToken.ThrowIfCancellationRequested();
            var language = LanguageFor(entry.RelativePath);
            if (language == "unknown")
            {
                files.Add(new RepositoryIntelligenceFile(entry.RelativePath, language, entry.SizeBytes, [], []));
                continue;
            }

            if (entry.SizeBytes > MaxFileBytes || aggregate + entry.SizeBytes > MaxAggregateBytes)
            {
                files.Add(new RepositoryIntelligenceFile(entry.RelativePath, language, entry.SizeBytes, [], []));
                continue;
            }

            string text;
            try
            {
                using var stream = new FileStream(entry.AbsolutePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 64 * 1024, FileOptions.SequentialScan);
                using var reader = new StreamReader(stream, new UTF8Encoding(false, true), detectEncodingFromByteOrderMarks: true);
                text = reader.ReadToEnd();
            }
            catch (DecoderFallbackException)
            {
                files.Add(new RepositoryIntelligenceFile(entry.RelativePath, "binary_or_non_utf8", entry.SizeBytes, [], []));
                continue;
            }

            aggregate += entry.SizeBytes;
            var symbols = new List<RepositoryIntelligenceSymbol>();
            var imports = new SortedSet<string>(StringComparer.Ordinal);
            var lines = text.Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n').Split('\n');
            for (var index = 0; index < lines.Length; index++)
            {
                context.CancellationToken.ThrowIfCancellationRequested();
                ExtractLine(language, entry.RelativePath, index + 1, lines[index], symbols, imports);
            }
            files.Add(new RepositoryIntelligenceFile(entry.RelativePath, language, entry.SizeBytes, symbols, imports.ToArray()));
        }

        var relations = BuildRelations(files);
        return Task.FromResult(new RepositoryIntelligenceProviderResult(files, relations));
    }

    private static string LanguageFor(string path) => Path.GetExtension(path).ToLowerInvariant() switch
    {
        ".cs" => "csharp",
        ".swift" => "swift",
        ".py" => "python",
        ".js" or ".jsx" => "javascript",
        ".ts" or ".tsx" => "typescript",
        ".mjs" or ".cjs" => "javascript",
        ".json" or ".md" or ".yml" or ".yaml" or ".toml" or ".xml" or ".props" or ".targets" => "data",
        _ => "unknown",
    };

    private static void ExtractLine(
        string language,
        string path,
        int line,
        string text,
        List<RepositoryIntelligenceSymbol> symbols,
        SortedSet<string> imports)
    {
        Match? symbol = null;
        if (language == "csharp")
        {
            symbol = CSharpSymbol.Match(text);
            if (!symbol.Success) symbol = CSharpMethod.Match(text);
            var trimmed = text.Trim();
            if (trimmed.StartsWith("using ", StringComparison.Ordinal))
            {
                var value = trimmed[6..].Trim().TrimEnd(';');
                var equal = value.IndexOf('=');
                if (equal >= 0) value = value[(equal + 1)..].Trim();
                if (value.Length > 0) imports.Add(value);
            }
        }
        else if (language == "swift")
        {
            symbol = SwiftSymbol.Match(text);
            var trimmed = text.Trim();
            if (trimmed.StartsWith("import ", StringComparison.Ordinal))
            {
                var value = trimmed[7..].Trim();
                if (value.Length > 0) imports.Add(value);
            }
        }
        else if (language == "python")
        {
            symbol = PythonSymbol.Match(text);
            var trimmed = text.Trim();
            if (trimmed.StartsWith("import ", StringComparison.Ordinal))
            {
                foreach (var value in trimmed[7..].Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
                    imports.Add(value.Split(' ', 2)[0]);
            }
            else if (trimmed.StartsWith("from ", StringComparison.Ordinal))
            {
                var value = trimmed[5..].Split(' ', 2)[0];
                if (value.Length > 0) imports.Add(value);
            }
        }
        else if (language is "javascript" or "typescript")
        {
            symbol = JsSymbol.Match(text);
            if (!symbol.Success) symbol = JsConstSymbol.Match(text);
            var trimmed = text.Trim();
            var from = trimmed.LastIndexOf(" from ", StringComparison.Ordinal);
            if (from >= 0) TryAddQuotedImport(trimmed[(from + 6)..], imports);
            else if (trimmed.StartsWith("import ", StringComparison.Ordinal)) TryAddQuotedImport(trimmed[7..], imports);
            var require = trimmed.IndexOf("require(", StringComparison.Ordinal);
            if (require >= 0) TryAddQuotedImport(trimmed[(require + 8)..], imports);
        }

        if (symbol is { Success: true })
        {
            var name = symbol.Groups["name"].Value;
            var kind = symbol.Groups["kind"].Success ? symbol.Groups["kind"].Value.Replace(" ", "_", StringComparison.Ordinal) : "binding";
            if (name.Length > 0 && symbols.Count < 2048)
                symbols.Add(new RepositoryIntelligenceSymbol(name, kind, path, line));
        }
    }

    private static void TryAddQuotedImport(string value, SortedSet<string> imports)
    {
        var start = value.IndexOfAny(['\'', '"']);
        if (start < 0) return;
        var quote = value[start];
        var end = value.IndexOf(quote, start + 1);
        if (end <= start + 1) return;
        imports.Add(value[(start + 1)..end]);
    }

    private static IReadOnlyList<RepositoryIntelligenceRelation> BuildRelations(IReadOnlyList<RepositoryIntelligenceFile> files)
    {
        var byStem = files
            .GroupBy(file => Path.GetFileNameWithoutExtension(file.Path), StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.Select(file => file.Path).ToArray(), StringComparer.OrdinalIgnoreCase);
        var result = new List<RepositoryIntelligenceRelation>();
        foreach (var file in files)
        {
            var targets = new Dictionary<string, (string Reason, double Score)>(StringComparer.Ordinal);
            foreach (var import in file.Imports)
            {
                var token = import.Replace('\\', '/').Split('/', StringSplitOptions.RemoveEmptyEntries).LastOrDefault() ?? import;
                token = Path.GetFileNameWithoutExtension(token);
                if (token.Length == 0 || !byStem.TryGetValue(token, out var candidates)) continue;
                foreach (var candidate in candidates)
                {
                    if (candidate == file.Path) continue;
                    targets[candidate] = ("import", 1.0);
                }
            }

            foreach (var candidate in files)
            {
                if (candidate.Path == file.Path) continue;
                if (string.Equals(Path.GetDirectoryName(candidate.Path), Path.GetDirectoryName(file.Path), StringComparison.OrdinalIgnoreCase))
                {
                    if (!targets.ContainsKey(candidate.Path)) targets[candidate.Path] = ("same_directory", 0.25);
                }
            }

            foreach (var pair in targets.OrderByDescending(item => item.Value.Score).ThenBy(item => item.Key, StringComparer.Ordinal).Take(128))
                result.Add(new RepositoryIntelligenceRelation(file.Path, pair.Key, pair.Value.Reason, pair.Value.Score));
        }
        return result;
    }
}

internal sealed class RepositoryIntelligenceService
{
    public const string CacheSchemaVersion = "1";
    public const int MaxTrackedFiles = 20_000;

    private static readonly HashSet<string> IgnoredSegments = new(
        [".git", ".svn", ".hg", "node_modules", ".venv", "venv", "__pycache__", "bin", "obj", "dist", "build", "coverage", ".next", ".turbo", "vendor"],
        StringComparer.OrdinalIgnoreCase);

    private readonly SafePathResolver _resolver;
    private readonly IRepositoryIntelligenceProvider _provider;
    private readonly Func<string, CancellationToken, Task<string>> _gitRepo;
    private readonly Func<string, IReadOnlyList<string>, int, bool, CancellationToken, Task<string>> _runGit;
    private readonly Func<string, CancellationToken, Task<JsonObject>> _captureSourceState;
    private readonly string? _cacheRoot;

    internal string? CacheRootForTest => _cacheRoot;

    public RepositoryIntelligenceService(
        SafePathResolver resolver,
        Func<string, CancellationToken, Task<string>> gitRepo,
        Func<string, IReadOnlyList<string>, int, bool, CancellationToken, Task<string>> runGit,
        Func<string, CancellationToken, Task<JsonObject>> captureSourceState,
        IRepositoryIntelligenceProvider? provider = null,
        string? cacheRoot = null)
    {
        _resolver = resolver;
        _gitRepo = gitRepo;
        _runGit = runGit;
        _captureSourceState = captureSourceState;
        _provider = provider ?? new LexicalSymbolProvider();
        var workspace = Path.GetFullPath(_resolver.Root).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (cacheRoot is not null)
        {
            var explicitRoot = Path.GetFullPath(cacheRoot);
            if (IsWithinWorkspace(explicitRoot, workspace))
                throw new FileMcpException("Repository intelligence cache must be outside the workspace");
            _cacheRoot = explicitRoot;
        }
        else
        {
            _cacheRoot = SelectDefaultCacheRoot(workspace);
        }
    }

    public async Task<RepositoryIntelligenceSnapshot> GetOrBuildAsync(string repoPath, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var repo = await _gitRepo(repoPath, cancellationToken).ConfigureAwait(false);
        var source = await _captureSourceState(repoPath, cancellationToken).ConfigureAwait(false);
        var sourceStateId = source["source_state_id"]?.GetValue<string>()
            ?? throw new FileMcpException("Repository intelligence requires SourceStateRef identity");

        var cachePath = _cacheRoot is null ? null : CachePath(repo, sourceStateId);
        if (cachePath is not null)
        {
            var cached = TryLoadCache(cachePath, sourceStateId);
            if (cached is not null) return cached with { CacheHit = true };
        }

        var inventoryRaw = await _runGit(
            repo,
            ["ls-files", "-z", "--cached"],
            FileMcpConstants.MaxGitSafetyOutputBytes,
            false,
            cancellationToken).ConfigureAwait(false);
        if (inventoryRaw.Contains("[...truncated ", StringComparison.Ordinal) && inventoryRaw.EndsWith(" bytes...]", StringComparison.Ordinal))
            throw new FileMcpException("Repository intelligence Git inventory exceeded the safety scan limit");

        var paths = inventoryRaw.Split('\0', StringSplitOptions.RemoveEmptyEntries)
            .Select(path => path.Replace('\\', '/'))
            .Where(path => !IsIgnored(path))
            .Distinct(StringComparer.Ordinal)
            .OrderBy(path => path, StringComparer.Ordinal)
            .ToArray();
        if (paths.Length > MaxTrackedFiles)
            throw new FileMcpException($"Repository intelligence tracked inventory exceeds {MaxTrackedFiles} files");

        var repoFull = Path.GetFullPath(repo);
        var files = new List<(string RelativePath, string AbsolutePath, long SizeBytes)>();
        foreach (var path in paths)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (Path.IsPathRooted(path) || path.Split('/').Any(segment => segment == ".."))
                throw new FileMcpException("Repository intelligence inventory contains an invalid path");
            var absolute = Path.GetFullPath(Path.Combine(repoFull, path));
            if (!absolute.StartsWith(repoFull + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                throw new FileMcpException("Repository intelligence inventory escaped the repository");
            var sharedRelative = _resolver.RelativePath(absolute);
            _ = _resolver.Resolve(sharedRelative);
            if (!File.Exists(absolute)) continue;
            var attributes = File.GetAttributes(absolute);
            if ((attributes & FileAttributes.ReparsePoint) != 0) continue;
            files.Add((path, absolute, new FileInfo(absolute).Length));
        }

        var result = await _provider.BuildAsync(new RepositoryIntelligenceBuildContext(files, cancellationToken)).ConfigureAwait(false);
        var builtEpoch = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var generation = ComputeGeneration(sourceStateId, result);
        var snapshot = new RepositoryIntelligenceSnapshot(
            _provider.ProviderId,
            _provider.ProviderVersion,
            _provider.Completeness,
            sourceStateId,
            generation,
            builtEpoch,
            result.Files,
            result.Relations,
            false);
        if (cachePath is not null)
        {
            try
            {
                PersistCache(cachePath, snapshot);
                CleanupStaleGenerations(cachePath);
            }
            catch (IOException)
            {
            }
            catch (UnauthorizedAccessException)
            {
            }
        }
        return snapshot;
    }

    private static string? SelectDefaultCacheRoot(string workspace)
    {
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "FileMCP", "repository-intelligence-cache"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".filemcp", "repository-intelligence-cache"),
            Path.Combine(Path.GetTempPath(), "FileMCP", "repository-intelligence-cache"),
        };
        foreach (var raw in candidates)
        {
            if (string.IsNullOrWhiteSpace(raw)) continue;
            var candidate = Path.GetFullPath(raw);
            if (!IsWithinWorkspace(candidate, workspace)) return candidate;
        }
        return null;
    }

    private static bool IsWithinWorkspace(string candidate, string workspace)
    {
        var normalizedWorkspace = Path.GetFullPath(workspace).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var normalizedCandidate = Path.GetFullPath(candidate).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (string.Equals(normalizedCandidate, normalizedWorkspace, StringComparison.OrdinalIgnoreCase)) return true;
        return normalizedCandidate.StartsWith(normalizedWorkspace + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
    }

    private string CachePath(string repo, string sourceStateId)
    {
        var repoKey = Sha256(Path.GetFullPath(repo).ToUpperInvariant());
        var providerKey = Sha256(_provider.ProviderId + "\n" + _provider.ProviderVersion);
        return Path.Combine(_cacheRoot!, repoKey, providerKey, sourceStateId.Replace(':', '_') + ".json");
    }

    private RepositoryIntelligenceSnapshot? TryLoadCache(string path, string sourceStateId)
    {
        if (!File.Exists(path)) return null;
        try
        {
            using var stream = File.OpenRead(path);
            var root = JsonNode.Parse(stream)?.AsObject() ?? throw new JsonException("root missing");
            if (root["schema_version"]?.GetValue<string>() != CacheSchemaVersion ||
                root["provider_id"]?.GetValue<string>() != _provider.ProviderId ||
                root["provider_version"]?.GetValue<string>() != _provider.ProviderVersion ||
                root["completeness"]?.GetValue<string>() != _provider.Completeness ||
                root["source_state_id"]?.GetValue<string>() != sourceStateId)
                throw new JsonException("cache identity mismatch");

            var files = new List<RepositoryIntelligenceFile>();
            foreach (var node in root["files"]?.AsArray() ?? [])
            {
                var item = node!.AsObject();
                var pathValue = item["path"]!.GetValue<string>();
                var symbols = item["symbols"]?.AsArray().Select(symbolNode =>
                {
                    var symbol = symbolNode!.AsObject();
                    return new RepositoryIntelligenceSymbol(
                        symbol["name"]!.GetValue<string>(),
                        symbol["kind"]!.GetValue<string>(),
                        pathValue,
                        symbol["line"]!.GetValue<int>());
                }).ToArray() ?? [];
                var imports = item["imports"]?.AsArray().Select(value => value!.GetValue<string>()).ToArray() ?? [];
                files.Add(new RepositoryIntelligenceFile(
                    pathValue,
                    item["language"]!.GetValue<string>(),
                    item["size_bytes"]!.GetValue<long>(),
                    symbols,
                    imports));
            }
            var relations = root["relations"]?.AsArray().Select(node =>
            {
                var relation = node!.AsObject();
                return new RepositoryIntelligenceRelation(
                    relation["source"]!.GetValue<string>(),
                    relation["target"]!.GetValue<string>(),
                    relation["reason"]!.GetValue<string>(),
                    relation["score"]!.GetValue<double>());
            }).ToArray() ?? [];
            return new RepositoryIntelligenceSnapshot(
                _provider.ProviderId,
                _provider.ProviderVersion,
                _provider.Completeness,
                sourceStateId,
                root["generation_id"]!.GetValue<string>(),
                root["built_epoch_ms"]!.GetValue<long>(),
                files,
                relations,
                false);
        }
        catch
        {
            try { File.Delete(path); } catch { }
            return null;
        }
    }

    private void PersistCache(string path, RepositoryIntelligenceSnapshot snapshot)
    {
        var root = new JsonObject
        {
            ["schema_version"] = CacheSchemaVersion,
            ["provider_id"] = snapshot.ProviderId,
            ["provider_version"] = snapshot.ProviderVersion,
            ["completeness"] = snapshot.Completeness,
            ["source_state_id"] = snapshot.SourceStateId,
            ["generation_id"] = snapshot.GenerationId,
            ["built_epoch_ms"] = snapshot.BuiltEpochMs,
            ["files"] = new JsonArray(snapshot.Files.Select(file => (JsonNode)new JsonObject
            {
                ["path"] = file.Path,
                ["language"] = file.Language,
                ["size_bytes"] = file.SizeBytes,
                ["symbols"] = new JsonArray(file.Symbols.Select(symbol => (JsonNode)new JsonObject
                {
                    ["name"] = symbol.Name,
                    ["kind"] = symbol.Kind,
                    ["line"] = symbol.Line,
                }).ToArray()),
                ["imports"] = new JsonArray(file.Imports.Select(value => (JsonNode)JsonValue.Create(value)!).ToArray()),
            }).ToArray()),
            ["relations"] = new JsonArray(snapshot.Relations.Select(relation => (JsonNode)new JsonObject
            {
                ["source"] = relation.Source,
                ["target"] = relation.Target,
                ["reason"] = relation.Reason,
                ["score"] = relation.Score,
            }).ToArray()),
        };

        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temp = path + ".tmp-" + Guid.NewGuid().ToString("N");
        try
        {
            File.WriteAllText(temp, root.ToJsonString(new JsonSerializerOptions { WriteIndented = false }), new UTF8Encoding(false));
            File.Move(temp, path, overwrite: true);
        }
        finally
        {
            try { if (File.Exists(temp)) File.Delete(temp); } catch { }
        }
    }

    private static void CleanupStaleGenerations(string currentPath)
    {
        var directory = Path.GetDirectoryName(currentPath);
        if (string.IsNullOrEmpty(directory) || !Directory.Exists(directory)) return;
        try
        {
            foreach (var file in Directory.EnumerateFiles(directory, "*.json", SearchOption.TopDirectoryOnly))
            {
                if (string.Equals(Path.GetFullPath(file), Path.GetFullPath(currentPath), StringComparison.OrdinalIgnoreCase))
                    continue;
                try { File.Delete(file); } catch { }
            }
        }
        catch { }
    }

    private static bool IsIgnored(string path) =>
        path.Split('/', StringSplitOptions.RemoveEmptyEntries).Any(segment => IgnoredSegments.Contains(segment));

    private static string ComputeGeneration(string sourceStateId, RepositoryIntelligenceProviderResult result)
    {
        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        Append(hash, sourceStateId);
        foreach (var file in result.Files.OrderBy(file => file.Path, StringComparer.Ordinal))
        {
            Append(hash, file.Path);
            Append(hash, file.Language);
            Append(hash, file.SizeBytes.ToString(System.Globalization.CultureInfo.InvariantCulture));
            foreach (var symbol in file.Symbols) Append(hash, symbol.Kind + ":" + symbol.Name + ":" + symbol.Line);
            foreach (var import in file.Imports) Append(hash, "import:" + import);
        }
        foreach (var relation in result.Relations.OrderBy(item => item.Source, StringComparer.Ordinal).ThenBy(item => item.Target, StringComparer.Ordinal))
            Append(hash, relation.Source + ">" + relation.Target + ":" + relation.Reason + ":" + relation.Score.ToString("R", System.Globalization.CultureInfo.InvariantCulture));
        return "sha256:" + Convert.ToHexString(hash.GetHashAndReset()).ToLowerInvariant();
    }

    private static void Append(IncrementalHash hash, string value)
    {
        hash.AppendData(Encoding.UTF8.GetBytes(value));
        hash.AppendData([0]);
    }

    private static string Sha256(string value) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
}
