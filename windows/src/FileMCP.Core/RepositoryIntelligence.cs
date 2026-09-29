using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace FileMCP.Core;

internal sealed class RepositoryIntelligenceOptions
{
    public string? CacheRootDirectory { get; init; }
    public int MaxTrackedFiles { get; init; } = 20_000;
    public long MaxAggregateSourceBytes { get; init; } = 50_000_000;
    public int MaxFileBytes { get; init; } = 1_000_000;
    public int MaxSymbolsPerFile { get; init; } = 512;
    public int MaxImportsPerFile { get; init; } = 256;
    public int MaxRelations { get; init; } = 20_000;
    public Action<string>? StageForTests { get; init; }
}

internal sealed record RepositorySymbol(string Name, string Kind, int Line);
internal sealed record RepositoryImport(string Target, int Line);
internal sealed record RepositoryFileIntelligence(
    string RelativePath,
    string Language,
    long SizeBytes,
    string ContentHash,
    IReadOnlyList<RepositorySymbol> Symbols,
    IReadOnlyList<RepositoryImport> Imports,
    bool SupportedLanguage);
internal sealed record RepositoryRelation(string Source, string Target, string Kind, double Score, int Rank);

internal interface IRepositoryIntelligenceProvider
{
    string ProviderId { get; }
    string ProviderVersion { get; }
    string Completeness { get; }
    string ParserProfileHash { get; }
    bool Supports(string relativePath);
    RepositoryFileIntelligence Analyze(
        string relativePath,
        byte[] utf8Content,
        int maxSymbols,
        int maxImports,
        CancellationToken cancellationToken,
        ToolExecutionContext? context);
}

internal sealed class LexicalSymbolProvider : IRepositoryIntelligenceProvider
{
    public const string Id = "lexical-symbols";
    public const string Version = "1.0.0";
    public string ProviderId => Id;
    public string ProviderVersion => Version;
    public string Completeness => "heuristic";
    public string ParserProfileHash => "sha256:" + Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes("lexical-symbols|1.0.0|patterns-v1|imports-v1"))).ToLowerInvariant();

    private static readonly Dictionary<string, string> Languages = new(StringComparer.OrdinalIgnoreCase)
    {
        [".cs"] = "csharp",
        [".swift"] = "swift",
        [".py"] = "python",
        [".js"] = "javascript",
        [".jsx"] = "javascript",
        [".mjs"] = "javascript",
        [".cjs"] = "javascript",
        [".ts"] = "typescript",
        [".tsx"] = "typescript",
        [".mts"] = "typescript",
        [".cts"] = "typescript",
        [".java"] = "java",
        [".kt"] = "kotlin",
        [".kts"] = "kotlin",
        [".go"] = "go",
        [".rs"] = "rust",
        [".rb"] = "ruby",
        [".php"] = "php",
        [".c"] = "c",
        [".h"] = "c",
        [".cc"] = "cpp",
        [".cpp"] = "cpp",
        [".cxx"] = "cpp",
        [".hh"] = "cpp",
        [".hpp"] = "cpp",
        [".hxx"] = "cpp",
    };

    private sealed record PatternSpec(Regex Regex, string Kind);
    private static readonly RegexOptions PatternOptions =
        RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.Multiline;

    private static readonly Dictionary<string, PatternSpec[]> SymbolPatterns = new(StringComparer.Ordinal)
    {
        ["csharp"] =
        [
            S(@"^\s*(?:(?:public|private|protected|internal|static|sealed|abstract|partial|readonly|ref)\s+)*(?:class|struct|interface|enum|record)\s+([A-Za-z_][A-Za-z0-9_]*)", "type"),
            S(@"^\s*(?:(?:public|private|protected|internal|static|virtual|override|async|sealed|abstract|partial|extern|unsafe|new)\s+)*(?:[A-Za-z_][A-Za-z0-9_<>,.?\[\]\s]*\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;]*\)\s*(?:=>|\{)", "function"),
        ],
        ["swift"] =
        [
            S(@"^\s*(?:(?:public|private|fileprivate|internal|open|final|actor|indirect)\s+)*(?:class|struct|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)", "type"),
            S(@"^\s*(?:(?:public|private|fileprivate|internal|open|static|class|mutating|nonmutating|async)\s+)*func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", "function"),
        ],
        ["python"] =
        [
            S(@"^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)\b", "type"),
            S(@"^\s*(?:async\s+)?def\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", "function"),
        ],
        ["javascript"] =
        [
            S(@"^\s*(?:export\s+)?(?:default\s+)?class\s+([A-Za-z_$][A-Za-z0-9_$]*)", "type"),
            S(@"^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\(", "function"),
            S(@"^\s*(?:export\s+)?(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*(?:async\s*)?\([^=]*\)\s*=>", "function"),
        ],
        ["typescript"] =
        [
            S(@"^\s*(?:export\s+)?(?:default\s+)?(?:abstract\s+)?(?:class|interface|enum|type)\s+([A-Za-z_$][A-Za-z0-9_$]*)", "type"),
            S(@"^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\(", "function"),
            S(@"^\s*(?:export\s+)?(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*(?:async\s*)?\([^=]*\)\s*=>", "function"),
        ],
        ["java"] =
        [
            S(@"^\s*(?:(?:public|private|protected|abstract|final|static|sealed|non-sealed)\s+)*(?:class|interface|enum|record)\s+([A-Za-z_][A-Za-z0-9_]*)", "type"),
            S(@"^\s*(?:(?:public|private|protected|abstract|final|static|synchronized|native|default)\s+)*(?:[A-Za-z_][A-Za-z0-9_<>,.?\[\]\s]*\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;]*\)\s*(?:throws\s+[^{]+)?\{", "function"),
        ],
        ["kotlin"] =
        [
            S(@"^\s*(?:(?:public|private|protected|internal|open|final|sealed|data|enum|annotation|value)\s+)*(?:class|interface|object)\s+([A-Za-z_][A-Za-z0-9_]*)", "type"),
            S(@"^\s*(?:(?:public|private|protected|internal|open|final|override|suspend|inline|tailrec|operator|infix)\s+)*fun\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", "function"),
        ],
        ["go"] =
        [
            S(@"^\s*type\s+([A-Za-z_][A-Za-z0-9_]*)\s+(?:struct|interface)\b", "type"),
            S(@"^\s*func\s+(?:\([^)]*\)\s*)?([A-Za-z_][A-Za-z0-9_]*)\s*\(", "function"),
        ],
        ["rust"] =
        [
            S(@"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:struct|enum|trait|union|type)\s+([A-Za-z_][A-Za-z0-9_]*)", "type"),
            S(@"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?(?:unsafe\s+)?fn\s+([A-Za-z_][A-Za-z0-9_]*)\s*[<(]", "function"),
        ],
        ["ruby"] =
        [
            S(@"^\s*(?:class|module)\s+([A-Za-z_][A-Za-z0-9_:]*)", "type"),
            S(@"^\s*def\s+(?:self\.)?([A-Za-z_][A-Za-z0-9_!?=]*)", "function"),
        ],
        ["php"] =
        [
            S(@"^\s*(?:(?:abstract|final|readonly)\s+)*(?:class|interface|trait|enum)\s+([A-Za-z_][A-Za-z0-9_]*)", "type"),
            S(@"^\s*(?:(?:public|private|protected|static|final|abstract)\s+)*function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", "function"),
        ],
        ["c"] =
        [
            S(@"^\s*(?:typedef\s+)?(?:struct|enum|union)\s+([A-Za-z_][A-Za-z0-9_]*)", "type"),
            S(@"^\s*(?!if\b|for\b|while\b|switch\b)(?:[A-Za-z_][A-Za-z0-9_*\s]+\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;]*\)\s*\{", "function"),
        ],
        ["cpp"] =
        [
            S(@"^\s*(?:template\s*<[^>]+>\s*)?(?:class|struct|enum|union)\s+([A-Za-z_][A-Za-z0-9_]*)", "type"),
            S(@"^\s*(?!if\b|for\b|while\b|switch\b)(?:[A-Za-z_~][A-Za-z0-9_:<>,*&\s]+\s+)+([A-Za-z_~][A-Za-z0-9_]*)\s*\([^;]*\)\s*(?:const\s*)?\{", "function"),
        ],
    };

    private static readonly Dictionary<string, Regex[]> ImportPatterns = new(StringComparer.Ordinal)
    {
        ["csharp"] = [R(@"^\s*using\s+(?:static\s+)?(?:[A-Za-z_][A-Za-z0-9_]*\s*=\s*)?([A-Za-z_][A-Za-z0-9_.]*)\s*;")],
        ["swift"] = [R(@"^\s*import\s+(?:class\s+|struct\s+|enum\s+|protocol\s+|func\s+|var\s+)?([A-Za-z_][A-Za-z0-9_.]*)")],
        ["python"] =
        [
            R(@"^\s*from\s+([A-Za-z_][A-Za-z0-9_.]*)\s+import\b"),
            R(@"^\s*import\s+([A-Za-z_][A-Za-z0-9_.]*)"),
        ],
        ["javascript"] =
        [
            R(@"^\s*import(?:[\s\S]*?\sfrom\s*)?['""]([^'""]+)['""]"),
            R(@"^\s*(?:const|let|var).*?require\(\s*['""]([^'""]+)['""]\s*\)"),
        ],
        ["typescript"] =
        [
            R(@"^\s*import(?:[\s\S]*?\sfrom\s*)?['""]([^'""]+)['""]"),
            R(@"^\s*(?:const|let|var).*?require\(\s*['""]([^'""]+)['""]\s*\)"),
        ],
        ["java"] = [R(@"^\s*import\s+(?:static\s+)?([A-Za-z_][A-Za-z0-9_.*]*)\s*;")],
        ["kotlin"] = [R(@"^\s*import\s+([A-Za-z_][A-Za-z0-9_.*]*)")],
        ["go"] = [R(@"^\s*import\s+(?:[A-Za-z_][A-Za-z0-9_]*\s+)?""([^""]+)""")],
        ["rust"] = [R(@"^\s*use\s+([A-Za-z_][A-Za-z0-9_:]*)")],
        ["ruby"] = [R(@"^\s*require(?:_relative)?\s+['""]([^'""]+)['""]")],
        ["php"] = [R(@"^\s*use\s+([A-Za-z_\\][A-Za-z0-9_\\]*)\s*;")],
        ["c"] = [R(@"^\s*#\s*include\s*[<""]([^>""]+)[>""]")],
        ["cpp"] = [R(@"^\s*#\s*include\s*[<""]([^>""]+)[>""]")],
    };

    public bool Supports(string relativePath) => Languages.ContainsKey(Path.GetExtension(relativePath));

    public RepositoryFileIntelligence Analyze(
        string relativePath,
        byte[] utf8Content,
        int maxSymbols,
        int maxImports,
        CancellationToken cancellationToken,
        ToolExecutionContext? context)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (context is not null && !context.TryContinue())
            throw new OperationCanceledException("Repository intelligence indexing cancelled", context.CancellationToken);

        var extension = Path.GetExtension(relativePath);
        var language = Languages.TryGetValue(extension, out var known) ? known : "unknown";
        if (language == "unknown")
        {
            return new RepositoryFileIntelligence(
                relativePath,
                language,
                utf8Content.LongLength,
                FileVersionService.Sha256Tagged(utf8Content),
                [],
                [],
                false);
        }

        string text;
        try
        {
            text = new UTF8Encoding(false, true).GetString(utf8Content);
        }
        catch (DecoderFallbackException)
        {
            return new RepositoryFileIntelligence(
                relativePath,
                language,
                utf8Content.LongLength,
                FileVersionService.Sha256Tagged(utf8Content),
                [],
                [],
                true);
        }

        var symbols = new List<RepositorySymbol>();
        if (SymbolPatterns.TryGetValue(language, out var symbolPatterns))
        {
            foreach (var spec in symbolPatterns)
            {
                foreach (Match match in spec.Regex.Matches(text))
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    if (context is not null && !context.TryContinue())
                        throw new OperationCanceledException("Repository intelligence indexing cancelled", context.CancellationToken);
                    if (!match.Success || match.Groups.Count < 2 || string.IsNullOrWhiteSpace(match.Groups[1].Value)) continue;
                    symbols.Add(new RepositorySymbol(match.Groups[1].Value, spec.Kind, LineOf(text, match.Index)));
                    if (symbols.Count >= maxSymbols) break;
                }
                if (symbols.Count >= maxSymbols) break;
            }
        }

        var imports = new List<RepositoryImport>();
        if (ImportPatterns.TryGetValue(language, out var importPatterns))
        {
            foreach (var regex in importPatterns)
            {
                foreach (Match match in regex.Matches(text))
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    if (context is not null && !context.TryContinue())
                        throw new OperationCanceledException("Repository intelligence indexing cancelled", context.CancellationToken);
                    if (!match.Success || match.Groups.Count < 2 || string.IsNullOrWhiteSpace(match.Groups[1].Value)) continue;
                    imports.Add(new RepositoryImport(match.Groups[1].Value, LineOf(text, match.Index)));
                    if (imports.Count >= maxImports) break;
                }
                if (imports.Count >= maxImports) break;
            }
        }

        return new RepositoryFileIntelligence(
            relativePath,
            language,
            utf8Content.LongLength,
            FileVersionService.Sha256Tagged(utf8Content),
            symbols
                .OrderBy(symbol => symbol.Line)
                .ThenBy(symbol => symbol.Name, StringComparer.Ordinal)
                .ToArray(),
            imports
                .OrderBy(importItem => importItem.Line)
                .ThenBy(importItem => importItem.Target, StringComparer.Ordinal)
                .ToArray(),
            true);
    }

    private static PatternSpec S(string pattern, string kind) => new(new Regex(pattern, PatternOptions), kind);
    private static Regex R(string pattern) => new(pattern, PatternOptions);

    private static int LineOf(string text, int index)
    {
        var line = 1;
        for (var i = 0; i < index && i < text.Length; i++)
            if (text[i] == '\n') line++;
        return line;
    }
}

internal sealed partial class LocalTools
{
    private const string RepositoryIntelligenceSchemaVersion = "1.0.0";
    private static readonly HashSet<string> RepositoryIntelligenceIgnoredDirectories = new(StringComparer.OrdinalIgnoreCase)
    {
        ".git", ".hg", ".svn", ".venv", "venv", "node_modules", "__pycache__",
        "build", "dist", "out", "target", "coverage", ".next", ".turbo", "vendor",
        "generated", "gen", "DerivedData", "Pods",
    };

    private static readonly HashSet<string> RepositoryIntelligenceBinaryExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".ico", ".pdf", ".zip", ".gz",
        ".tar", ".7z", ".rar", ".exe", ".dll", ".so", ".dylib", ".a", ".lib", ".pdb",
        ".woff", ".woff2", ".ttf", ".otf", ".mp3", ".wav", ".mp4", ".mov", ".avi", ".sqlite",
        ".sqlite3", ".db", ".bin", ".class", ".jar", ".wasm",
    };

    internal async Task<JsonObject> CaptureRepositoryIntelligenceAsync(
        string repoPath,
        RepositoryIntelligenceOptions? options = null,
        ToolExecutionContext? context = null,
        CancellationToken cancellationToken = default,
        IRepositoryIntelligenceProvider? provider = null)
    {
        options ??= new RepositoryIntelligenceOptions();
        ValidateRepositoryIntelligenceOptions(options);
        provider ??= new LexicalSymbolProvider();

        cancellationToken.ThrowIfCancellationRequested();
        if (context is not null && !context.TryContinue())
            return CancelledRepositoryIntelligence(provider, "cancelled");

        var repo = await GitRepoAsync(repoPath, cancellationToken).ConfigureAwait(false);
        var sourceState = await CaptureSourceStateRefAsync(repoPath, null, cancellationToken).ConfigureAwait(false);
        var sourceStateId = sourceState["source_state_id"]?.GetValue<string>()
            ?? throw new FileMcpException("Repository intelligence SourceStateRef identity is unavailable");
        var repoFull = Path.GetFullPath(repo);
        var cache = RepositoryIntelligenceCache.Create(repoFull, _resolver.Root, options);

        var cached = cache.TryLoad(sourceStateId, provider, out var cacheStatus);
        if (cached is not null)
        {
            cached["cache_status"] = "hit";
            cached["cache_recovery"] = cacheStatus;
            return cached;
        }

        options.StageForTests?.Invoke("before_inventory");
        cancellationToken.ThrowIfCancellationRequested();
        var inventoryRaw = await RunGitAsync(
            repo,
            ["ls-files", "--cached", "-z", "--"],
            FileMcpConstants.MaxGitSafetyOutputBytes,
            trimOutput: false,
            cancellationToken).ConfigureAwait(false);
        EnsureCompleteGitSafetyOutput(inventoryRaw, "Repository intelligence tracked inventory");
        var tracked = inventoryRaw
            .Split('\0', StringSplitOptions.RemoveEmptyEntries)
            .Select(NormalizeRepositoryInventoryPath)
            .Where(path => path is not null)
            .Cast<string>()
            .Distinct(StringComparer.Ordinal)
            .OrderBy(path => path, StringComparer.Ordinal)
            .ToArray();

        var files = new List<RepositoryFileIntelligence>();
        var skippedIgnored = 0;
        var skippedBinary = 0;
        var skippedOversized = 0;
        var skippedMissing = 0;
        var truncated = false;
        var truncationReason = "none";
        long aggregateReadBytes = 0;
        var visited = 0;

        foreach (var relative in tracked)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (context is not null && !context.TryContinue())
            {
                truncated = true;
                truncationReason = context.TruncationReason == "none" ? "cancelled" : context.TruncationReason;
                break;
            }
            if (visited >= options.MaxTrackedFiles)
            {
                truncated = true;
                truncationReason = "max_tracked_files";
                break;
            }
            visited++;
            if (context is not null && !context.TryVisitEntry())
            {
                truncated = true;
                truncationReason = context.TruncationReason;
                break;
            }

            if (ShouldIgnoreRepositoryPath(relative))
            {
                skippedIgnored++;
                continue;
            }

            var extension = Path.GetExtension(relative);
            if (RepositoryIntelligenceBinaryExtensions.Contains(extension))
            {
                skippedBinary++;
                continue;
            }

            var absolute = Path.GetFullPath(Path.Combine(repoFull, relative.Replace('/', Path.DirectorySeparatorChar)));
            var sharedRelative = _resolver.RelativePath(absolute);
            var target = _resolver.Resolve(sharedRelative);
            if (!File.Exists(target))
            {
                skippedMissing++;
                continue;
            }

            var info = new FileInfo(target);
            if (info.Length < 0 || info.Length > options.MaxFileBytes)
            {
                skippedOversized++;
                continue;
            }

            if (!provider.Supports(relative))
            {
                files.Add(new RepositoryFileIntelligence(
                    relative,
                    "unknown",
                    info.Length,
                    "unread",
                    [],
                    [],
                    false));
                continue;
            }

            if (info.Length > options.MaxAggregateSourceBytes - aggregateReadBytes)
            {
                truncated = true;
                truncationReason = "max_aggregate_source_bytes";
                break;
            }
            if (context is not null && !context.TryScanFile(info.Length))
            {
                truncated = true;
                truncationReason = context.TruncationReason;
                break;
            }

            var bytes = await ReadRepositoryIntelligenceFileAsync(target, info.Length, cancellationToken).ConfigureAwait(false);
            aggregateReadBytes += bytes.LongLength;
            if (LooksBinary(bytes))
            {
                skippedBinary++;
                continue;
            }

            var analyzed = provider.Analyze(
                relative,
                bytes,
                options.MaxSymbolsPerFile,
                options.MaxImportsPerFile,
                cancellationToken,
                context);
            files.Add(analyzed);
        }

        var relations = BuildRepositoryRelations(files, options.MaxRelations, out var relationTruncated);
        if (relationTruncated && !truncated)
        {
            truncated = true;
            truncationReason = "max_relations";
        }

        options.StageForTests?.Invoke("before_source_state_recheck");
        cancellationToken.ThrowIfCancellationRequested();
        var sourceStateAfter = await CaptureSourceStateRefAsync(repoPath, null, cancellationToken).ConfigureAwait(false);
        var sourceStateAfterId = sourceStateAfter["source_state_id"]?.GetValue<string>()
            ?? throw new FileMcpException("Repository intelligence post-index SourceStateRef identity is unavailable");
        if (!string.Equals(sourceStateAfterId, sourceStateId, StringComparison.Ordinal))
        {
            options.StageForTests?.Invoke("source_state_changed");
            throw new FileMcpException("Repository changed while intelligence index was being built");
        }

        var snapshot = BuildRepositoryIntelligenceSnapshot(
            sourceStateAfter,
            sourceStateAfterId,
            provider,
            files,
            relations,
            tracked.Length,
            visited,
            aggregateReadBytes,
            skippedIgnored,
            skippedBinary,
            skippedOversized,
            skippedMissing,
            truncated,
            truncationReason);
        snapshot["cache_status"] = "rebuilt";
        snapshot["cache_recovery"] = cacheStatus;

        if (!truncated)
        {
            options.StageForTests?.Invoke("before_cache_write");
            cache.Save(snapshot);
        }
        return snapshot;
    }

    private static JsonObject CancelledRepositoryIntelligence(IRepositoryIntelligenceProvider provider, string reason) => new()
    {
        ["schema_version"] = RepositoryIntelligenceSchemaVersion,
        ["provider_id"] = provider.ProviderId,
        ["provider_version"] = provider.ProviderVersion,
        ["completeness"] = provider.Completeness,
        ["parser_profile_hash"] = provider.ParserProfileHash,
        ["source_state_id"] = null,
        ["grants_authority"] = false,
        ["raw_source_persisted"] = false,
        ["cache_status"] = "not_checked",
        ["cache_recovery"] = "none",
        ["tracked_inventory_count"] = 0,
        ["visited_count"] = 0,
        ["indexed_file_count"] = 0,
        ["relation_count"] = 0,
        ["aggregate_source_bytes"] = 0,
        ["truncated"] = true,
        ["truncation_reason"] = reason,
        ["files"] = new JsonArray(),
        ["relations"] = new JsonArray(),
    };

    private static JsonObject BuildRepositoryIntelligenceSnapshot(
        JsonObject sourceState,
        string sourceStateId,
        IRepositoryIntelligenceProvider provider,
        IReadOnlyList<RepositoryFileIntelligence> files,
        IReadOnlyList<RepositoryRelation> relations,
        int trackedCount,
        int visited,
        long aggregateReadBytes,
        int skippedIgnored,
        int skippedBinary,
        int skippedOversized,
        int skippedMissing,
        bool truncated,
        string truncationReason)
    {
        var fileArray = new JsonArray();
        foreach (var file in files.OrderBy(file => file.RelativePath, StringComparer.Ordinal))
        {
            var symbols = new JsonArray();
            foreach (var symbol in file.Symbols)
            {
                symbols.Add(new JsonObject
                {
                    ["name"] = symbol.Name,
                    ["kind"] = symbol.Kind,
                    ["line"] = symbol.Line,
                });
            }
            var imports = new JsonArray();
            foreach (var importItem in file.Imports)
            {
                imports.Add(new JsonObject
                {
                    ["target"] = importItem.Target,
                    ["line"] = importItem.Line,
                });
            }
            fileArray.Add(new JsonObject
            {
                ["path"] = file.RelativePath,
                ["language"] = file.Language,
                ["size_bytes"] = file.SizeBytes,
                ["content_hash"] = file.ContentHash,
                ["supported_language"] = file.SupportedLanguage,
                ["symbols"] = symbols,
                ["imports"] = imports,
            });
        }

        var relationArray = new JsonArray();
        foreach (var relation in relations)
        {
            relationArray.Add(new JsonObject
            {
                ["source"] = relation.Source,
                ["target"] = relation.Target,
                ["kind"] = relation.Kind,
                ["score"] = relation.Score,
                ["rank"] = relation.Rank,
            });
        }

        return new JsonObject
        {
            ["schema_version"] = RepositoryIntelligenceSchemaVersion,
            ["provider_id"] = provider.ProviderId,
            ["provider_version"] = provider.ProviderVersion,
            ["completeness"] = provider.Completeness,
            ["parser_profile_hash"] = provider.ParserProfileHash,
            ["source_state_provider_version"] = sourceState["provider_version"]?.GetValue<string>(),
            ["grants_authority"] = false,
            ["raw_source_persisted"] = false,
            ["source_state_id"] = sourceStateId,
            ["tracked_inventory_count"] = trackedCount,
            ["visited_count"] = visited,
            ["indexed_file_count"] = files.Count,
            ["relation_count"] = relations.Count,
            ["aggregate_source_bytes"] = aggregateReadBytes,
            ["skipped_ignored"] = skippedIgnored,
            ["skipped_binary"] = skippedBinary,
            ["skipped_oversized"] = skippedOversized,
            ["skipped_missing"] = skippedMissing,
            ["truncated"] = truncated,
            ["truncation_reason"] = truncationReason,
            ["files"] = fileArray,
            ["relations"] = relationArray,
        };
    }

    private static IReadOnlyList<RepositoryRelation> BuildRepositoryRelations(
        IReadOnlyList<RepositoryFileIntelligence> files,
        int maxRelations,
        out bool truncated)
    {
        var candidates = new List<(string Source, string Target, string Kind, double Score)>();
        var exactPath = files.ToDictionary(file => file.RelativePath, StringComparer.Ordinal);
        var byStem = files
            .GroupBy(file => Path.GetFileNameWithoutExtension(file.RelativePath), StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.Select(file => file.RelativePath).OrderBy(path => path, StringComparer.Ordinal).ToArray(), StringComparer.Ordinal);
        var symbolOwners = files
            .SelectMany(file => file.Symbols.Select(symbol => (symbol.Name, file.RelativePath)))
            .GroupBy(item => item.Name, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.Select(item => item.RelativePath).Distinct(StringComparer.Ordinal).OrderBy(path => path, StringComparer.Ordinal).ToArray(), StringComparer.Ordinal);

        var byDirectory = files
            .GroupBy(file => Path.GetDirectoryName(file.RelativePath.Replace('/', Path.DirectorySeparatorChar))?.Replace('\\', '/') ?? "", StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.Select(file => file.RelativePath).OrderBy(path => path, StringComparer.Ordinal).ToArray(), StringComparer.Ordinal);

        foreach (var file in files.OrderBy(file => file.RelativePath, StringComparer.Ordinal))
        {
            if (!file.SupportedLanguage)
            {
                var directory = Path.GetDirectoryName(file.RelativePath.Replace('/', Path.DirectorySeparatorChar))?.Replace('\\', '/') ?? "";
                if (byDirectory.TryGetValue(directory, out var peers))
                {
                    foreach (var peer in peers.Where(path => !string.Equals(path, file.RelativePath, StringComparison.Ordinal)).Take(4))
                        candidates.Add((file.RelativePath, peer, "file_level", 0.10));
                }
            }

            foreach (var importItem in file.Imports)
            {
                var resolved = ResolveImportRelation(file.RelativePath, importItem.Target, exactPath, byStem, symbolOwners);
                if (resolved is not null && !string.Equals(resolved.Value.Target, file.RelativePath, StringComparison.Ordinal))
                    candidates.Add((file.RelativePath, resolved.Value.Target, resolved.Value.Kind, resolved.Value.Score));
            }
        }

        var ordered = candidates
            .Distinct()
            .OrderByDescending(item => item.Score)
            .ThenBy(item => item.Source, StringComparer.Ordinal)
            .ThenBy(item => item.Target, StringComparer.Ordinal)
            .ThenBy(item => item.Kind, StringComparer.Ordinal)
            .Take(maxRelations + 1)
            .ToArray();
        truncated = ordered.Length > maxRelations;
        var take = truncated ? ordered.Take(maxRelations).ToArray() : ordered;
        return take
            .Select((item, index) => new RepositoryRelation(item.Source, item.Target, item.Kind, item.Score, index + 1))
            .ToArray();
    }

    private static (string Target, string Kind, double Score)? ResolveImportRelation(
        string sourcePath,
        string importTarget,
        IReadOnlyDictionary<string, RepositoryFileIntelligence> exactPath,
        IReadOnlyDictionary<string, string[]> byStem,
        IReadOnlyDictionary<string, string[]> symbolOwners)
    {
        var normalized = importTarget.Replace('\\', '/').Trim();
        if (normalized.Length == 0) return null;

        if (normalized.StartsWith("./", StringComparison.Ordinal) || normalized.StartsWith("../", StringComparison.Ordinal))
        {
            var sourceDir = Path.GetDirectoryName(sourcePath.Replace('/', Path.DirectorySeparatorChar)) ?? "";
            var combined = Path.GetFullPath(Path.Combine(Path.DirectorySeparatorChar.ToString(), sourceDir, normalized.Replace('/', Path.DirectorySeparatorChar)))
                .TrimStart(Path.DirectorySeparatorChar)
                .Replace('\\', '/');
            foreach (var candidate in CandidateModulePaths(combined))
                if (exactPath.ContainsKey(candidate)) return (candidate, "import", 1.0);
        }

        var last = normalized
            .TrimEnd('/', '*')
            .Split(['/', '.', ':'], StringSplitOptions.RemoveEmptyEntries)
            .LastOrDefault();
        if (last is null) return null;
        if (byStem.TryGetValue(last, out var files) && files.Length == 1)
            return (files[0], "import_name", 0.75);
        if (symbolOwners.TryGetValue(last, out var owners) && owners.Length == 1)
            return (owners[0], "symbol_reference", 0.55);
        return null;
    }

    private static IEnumerable<string> CandidateModulePaths(string path)
    {
        yield return path;
        if (Path.HasExtension(path)) yield break;
        foreach (var extension in new[] { ".cs", ".swift", ".py", ".js", ".jsx", ".ts", ".tsx", ".java", ".kt", ".go", ".rs", ".rb", ".php", ".c", ".cc", ".cpp", ".h", ".hpp" })
            yield return path + extension;
        foreach (var extension in new[] { ".js", ".ts", ".tsx", ".py" })
            yield return path.TrimEnd('/') + "/index" + extension;
    }

    private static string? NormalizeRepositoryInventoryPath(string raw)
    {
        var path = raw.Replace('\\', '/').Trim();
        if (path.Length == 0 || path.StartsWith("/", StringComparison.Ordinal)) return null;
        var segments = path.Split('/', StringSplitOptions.None);
        if (segments.Any(segment => segment is "" or "." or "..")) return null;
        return string.Join("/", segments);
    }

    private static bool ShouldIgnoreRepositoryPath(string relativePath)
    {
        var segments = relativePath.Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (segments.Any(segment => RepositoryIntelligenceIgnoredDirectories.Contains(segment))) return true;
        var name = segments.Length == 0 ? relativePath : segments[^1];
        return name.EndsWith(".g.cs", StringComparison.OrdinalIgnoreCase) ||
               name.EndsWith(".generated.cs", StringComparison.OrdinalIgnoreCase) ||
               name.EndsWith(".designer.cs", StringComparison.OrdinalIgnoreCase) ||
               name.EndsWith(".min.js", StringComparison.OrdinalIgnoreCase) ||
               name.EndsWith(".map", StringComparison.OrdinalIgnoreCase);
    }

    private static bool LooksBinary(byte[] data)
    {
        var probe = Math.Min(data.Length, 8192);
        for (var i = 0; i < probe; i++)
            if (data[i] == 0) return true;
        return false;
    }

    private static async Task<byte[]> ReadRepositoryIntelligenceFileAsync(
        string path,
        long expectedSize,
        CancellationToken cancellationToken)
    {
        if (expectedSize > int.MaxValue) throw new FileMcpException("Repository intelligence file is too large");
        var result = new byte[(int)expectedSize];
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 64 * 1024, FileOptions.SequentialScan);
        var offset = 0;
        while (offset < result.Length)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var read = await stream.ReadAsync(result.AsMemory(offset), cancellationToken).ConfigureAwait(false);
            if (read == 0) break;
            offset += read;
        }
        if (offset != result.Length)
            throw new FileMcpException("Repository intelligence source changed while being read");
        var after = new FileInfo(path);
        if (!after.Exists || after.Length != expectedSize)
            throw new FileMcpException("Repository intelligence source changed while being read");
        return result;
    }

    private static void ValidateRepositoryIntelligenceOptions(RepositoryIntelligenceOptions options)
    {
        if (options.MaxTrackedFiles is < 1 or > 100_000) throw new ArgumentOutOfRangeException(nameof(options.MaxTrackedFiles));
        if (options.MaxAggregateSourceBytes is < 1 or > 500_000_000) throw new ArgumentOutOfRangeException(nameof(options.MaxAggregateSourceBytes));
        if (options.MaxFileBytes is < 1 or > 10_000_000) throw new ArgumentOutOfRangeException(nameof(options.MaxFileBytes));
        if (options.MaxSymbolsPerFile is < 1 or > 4096) throw new ArgumentOutOfRangeException(nameof(options.MaxSymbolsPerFile));
        if (options.MaxImportsPerFile is < 1 or > 4096) throw new ArgumentOutOfRangeException(nameof(options.MaxImportsPerFile));
        if (options.MaxRelations is < 1 or > 100_000) throw new ArgumentOutOfRangeException(nameof(options.MaxRelations));
    }

    private sealed class RepositoryIntelligenceCache
    {
        private readonly string _path;
        private readonly RepositoryIntelligenceOptions _options;

        private RepositoryIntelligenceCache(string path, RepositoryIntelligenceOptions options)
        {
            _path = path;
            _options = options;
        }

        public static RepositoryIntelligenceCache Create(string repo, string workspaceRoot, RepositoryIntelligenceOptions options)
        {
            var root = Path.GetFullPath(options.CacheRootDirectory ?? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "FileMCP",
                "repo-intelligence-v1"));
            var workspace = Path.GetFullPath(workspaceRoot).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (IsSameOrDescendant(root, workspace))
                throw new FileMcpException("Repository intelligence cache root must be outside the workspace/repository");

            Directory.CreateDirectory(root);
            var repoKey = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Path.GetFullPath(repo).ToUpperInvariant()))).ToLowerInvariant();
            return new RepositoryIntelligenceCache(Path.Combine(root, repoKey + ".json"), options);
        }

        public JsonObject? TryLoad(
            string sourceStateId,
            IRepositoryIntelligenceProvider provider,
            out string recovery)
        {
            recovery = "none";
            if (!File.Exists(_path)) return null;
            try
            {
                var info = new FileInfo(_path);
                if (info.Length <= 0 || info.Length > 64L * 1024 * 1024)
                    throw new FileMcpException("Repository intelligence cache size is invalid");
                var parsed = JsonNode.Parse(File.ReadAllText(_path, Encoding.UTF8)) as JsonObject
                    ?? throw new FileMcpException("Repository intelligence cache root must be an object");
                ValidateCacheShape(parsed);
                var stale =
                    !string.Equals(parsed["source_state_id"]?.GetValue<string>(), sourceStateId, StringComparison.Ordinal) ||
                    !string.Equals(parsed["provider_id"]?.GetValue<string>(), provider.ProviderId, StringComparison.Ordinal) ||
                    !string.Equals(parsed["provider_version"]?.GetValue<string>(), provider.ProviderVersion, StringComparison.Ordinal) ||
                    !string.Equals(parsed["completeness"]?.GetValue<string>(), provider.Completeness, StringComparison.Ordinal) ||
                    !string.Equals(parsed["parser_profile_hash"]?.GetValue<string>(), provider.ParserProfileHash, StringComparison.Ordinal);
                if (stale)
                {
                    recovery = "stale_deleted";
                    _options.StageForTests?.Invoke("cache_stale");
                    TryDelete();
                    return null;
                }
                _options.StageForTests?.Invoke("cache_hit");
                return parsed;
            }
            catch
            {
                recovery = "corrupt_deleted";
                _options.StageForTests?.Invoke("cache_corrupt");
                TryDelete();
                return null;
            }
        }

        public void Save(JsonObject snapshot)
        {
            var persisted = snapshot.DeepClone().AsObject();
            persisted.Remove("cache_status");
            persisted.Remove("cache_recovery");
            var bytes = Encoding.UTF8.GetBytes(persisted.ToJsonString(new JsonSerializerOptions { WriteIndented = false }));
            if (bytes.LongLength > 64L * 1024 * 1024)
                throw new FileMcpException("Repository intelligence cache metadata is too large");
            var directory = Path.GetDirectoryName(_path) ?? throw new FileMcpException("Repository intelligence cache path has no parent");
            Directory.CreateDirectory(directory);
            var temp = Path.Combine(directory, ".tmp_" + Convert.ToHexString(RandomNumberGenerator.GetBytes(12)).ToLowerInvariant());
            try
            {
                using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    stream.Write(bytes);
                    stream.Flush(flushToDisk: true);
                }
                File.Move(temp, _path, overwrite: true);
            }
            finally
            {
                try { if (File.Exists(temp)) File.Delete(temp); } catch { }
            }
        }

        private static void ValidateCacheShape(JsonObject parsed)
        {
            if (parsed["schema_version"]?.GetValue<string>() != RepositoryIntelligenceSchemaVersion)
                throw new FileMcpException("Repository intelligence cache schema mismatch");
            foreach (var key in new[] { "provider_id", "provider_version", "completeness", "parser_profile_hash", "source_state_id" })
                if (string.IsNullOrWhiteSpace(parsed[key]?.GetValue<string>()))
                    throw new FileMcpException("Repository intelligence cache metadata is incomplete");
            if (parsed["files"] is not JsonArray || parsed["relations"] is not JsonArray)
                throw new FileMcpException("Repository intelligence cache collections are invalid");
        }

        private void TryDelete()
        {
            try { File.Delete(_path); } catch { }
        }

        private static bool IsSameOrDescendant(string candidate, string parent)
        {
            var normalizedCandidate = Path.GetFullPath(candidate).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            var normalizedParent = Path.GetFullPath(parent).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            return string.Equals(normalizedCandidate, normalizedParent, StringComparison.OrdinalIgnoreCase) ||
                   normalizedCandidate.StartsWith(normalizedParent + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
        }
    }
}
