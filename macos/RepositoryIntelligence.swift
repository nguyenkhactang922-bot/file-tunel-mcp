import Foundation

struct RepositoryIntelligenceOptions {
    var cacheRootURL: URL?
    var maxTrackedFiles: Int = 20_000
    var maxAggregateSourceBytes: Int64 = 50_000_000
    var maxFileBytes: Int = 1_000_000
    var maxSymbolsPerFile: Int = 512
    var maxImportsPerFile: Int = 256
    var maxRelations: Int = 20_000
    var stageForTests: ((String) -> Void)?
}

struct RepositorySymbol {
    let name: String
    let kind: String
    let line: Int
}

struct RepositoryImport {
    let target: String
    let line: Int
}

struct RepositoryFileIntelligence {
    let relativePath: String
    let language: String
    let sizeBytes: Int64
    let contentHash: String
    let symbols: [RepositorySymbol]
    let imports: [RepositoryImport]
    let supportedLanguage: Bool
}

struct RepositoryRelation {
    let source: String
    let target: String
    let kind: String
    let score: Double
    let rank: Int
}

protocol RepositoryIntelligenceProvider {
    var providerID: String { get }
    var providerVersion: String { get }
    var completeness: String { get }
    var parserProfileHash: String { get }
    func supports(relativePath: String) -> Bool
    func analyze(
        relativePath: String,
        utf8Content: Data,
        maxSymbols: Int,
        maxImports: Int,
        context: ToolExecutionContext?
    ) throws -> RepositoryFileIntelligence
}

final class LexicalSymbolProvider: RepositoryIntelligenceProvider {
    static let id = "lexical-symbols"
    static let version = "1.0.0"

    let providerID = LexicalSymbolProvider.id
    let providerVersion = LexicalSymbolProvider.version
    let completeness = "heuristic"
    let parserProfileHash = FileVersionService.sha256Tagged("lexical-symbols|1.0.0|patterns-v1|imports-v1")

    private static let languages: [String: String] = [
        "cs": "csharp",
        "swift": "swift",
        "py": "python",
        "js": "javascript",
        "jsx": "javascript",
        "mjs": "javascript",
        "cjs": "javascript",
        "ts": "typescript",
        "tsx": "typescript",
        "mts": "typescript",
        "cts": "typescript",
        "java": "java",
        "kt": "kotlin",
        "kts": "kotlin",
        "go": "go",
        "rs": "rust",
        "rb": "ruby",
        "php": "php",
        "c": "c",
        "h": "c",
        "cc": "cpp",
        "cpp": "cpp",
        "cxx": "cpp",
        "hh": "cpp",
        "hpp": "cpp",
        "hxx": "cpp",
    ]

    private struct SymbolPattern {
        let regex: NSRegularExpression
        let kind: String
    }

    private static let symbolPatterns: [String: [SymbolPattern]] = [
        "csharp": [
            symbol(#"^\s*(?:(?:public|private|protected|internal|static|sealed|abstract|partial|readonly|ref)\s+)*(?:class|struct|interface|enum|record)\s+([A-Za-z_][A-Za-z0-9_]*)"#, "type"),
            symbol(#"^\s*(?:(?:public|private|protected|internal|static|virtual|override|async|sealed|abstract|partial|extern|unsafe|new)\s+)*(?:[A-Za-z_][A-Za-z0-9_<>,.?\[\]\s]*\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;]*\)\s*(?:=>|\{)"#, "function"),
        ],
        "swift": [
            symbol(#"^\s*(?:(?:public|private|fileprivate|internal|open|final|actor|indirect)\s+)*(?:class|struct|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)"#, "type"),
            symbol(#"^\s*(?:(?:public|private|fileprivate|internal|open|static|class|mutating|nonmutating|async)\s+)*func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("#, "function"),
        ],
        "python": [
            symbol(#"^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)\b"#, "type"),
            symbol(#"^\s*(?:async\s+)?def\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("#, "function"),
        ],
        "javascript": [
            symbol(#"^\s*(?:export\s+)?(?:default\s+)?class\s+([A-Za-z_$][A-Za-z0-9_$]*)"#, "type"),
            symbol(#"^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\("#, "function"),
            symbol(#"^\s*(?:export\s+)?(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*(?:async\s*)?\([^=]*\)\s*=>"#, "function"),
        ],
        "typescript": [
            symbol(#"^\s*(?:export\s+)?(?:default\s+)?(?:abstract\s+)?(?:class|interface|enum|type)\s+([A-Za-z_$][A-Za-z0-9_$]*)"#, "type"),
            symbol(#"^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\("#, "function"),
            symbol(#"^\s*(?:export\s+)?(?:const|let|var)\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*(?:async\s*)?\([^=]*\)\s*=>"#, "function"),
        ],
        "java": [
            symbol(#"^\s*(?:(?:public|private|protected|abstract|final|static|sealed|non-sealed)\s+)*(?:class|interface|enum|record)\s+([A-Za-z_][A-Za-z0-9_]*)"#, "type"),
            symbol(#"^\s*(?:(?:public|private|protected|abstract|final|static|synchronized|native|default)\s+)*(?:[A-Za-z_][A-Za-z0-9_<>,.?\[\]\s]*\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;]*\)\s*(?:throws\s+[^{]+)?\{"#, "function"),
        ],
        "kotlin": [
            symbol(#"^\s*(?:(?:public|private|protected|internal|open|final|sealed|data|enum|annotation|value)\s+)*(?:class|interface|object)\s+([A-Za-z_][A-Za-z0-9_]*)"#, "type"),
            symbol(#"^\s*(?:(?:public|private|protected|internal|open|final|override|suspend|inline|tailrec|operator|infix)\s+)*fun\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("#, "function"),
        ],
        "go": [
            symbol(#"^\s*type\s+([A-Za-z_][A-Za-z0-9_]*)\s+(?:struct|interface)\b"#, "type"),
            symbol(#"^\s*func\s+(?:\([^)]*\)\s*)?([A-Za-z_][A-Za-z0-9_]*)\s*\("#, "function"),
        ],
        "rust": [
            symbol(#"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:struct|enum|trait|union|type)\s+([A-Za-z_][A-Za-z0-9_]*)"#, "type"),
            symbol(#"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?(?:unsafe\s+)?fn\s+([A-Za-z_][A-Za-z0-9_]*)\s*[<(]"#, "function"),
        ],
        "ruby": [
            symbol(#"^\s*(?:class|module)\s+([A-Za-z_][A-Za-z0-9_:]*)"#, "type"),
            symbol(#"^\s*def\s+(?:self\.)?([A-Za-z_][A-Za-z0-9_!?=]*)"#, "function"),
        ],
        "php": [
            symbol(#"^\s*(?:(?:abstract|final|readonly)\s+)*(?:class|interface|trait|enum)\s+([A-Za-z_][A-Za-z0-9_]*)"#, "type"),
            symbol(#"^\s*(?:(?:public|private|protected|static|final|abstract)\s+)*function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("#, "function"),
        ],
        "c": [
            symbol(#"^\s*(?:typedef\s+)?(?:struct|enum|union)\s+([A-Za-z_][A-Za-z0-9_]*)"#, "type"),
            symbol(#"^\s*(?!if\b|for\b|while\b|switch\b)(?:[A-Za-z_][A-Za-z0-9_*\s]+\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;]*\)\s*\{"#, "function"),
        ],
        "cpp": [
            symbol(#"^\s*(?:template\s*<[^>]+>\s*)?(?:class|struct|enum|union)\s+([A-Za-z_][A-Za-z0-9_]*)"#, "type"),
            symbol(#"^\s*(?!if\b|for\b|while\b|switch\b)(?:[A-Za-z_~][A-Za-z0-9_:<>,*&\s]+\s+)+([A-Za-z_~][A-Za-z0-9_]*)\s*\([^;]*\)\s*(?:const\s*)?\{"#, "function"),
        ],
    ]

    private static let importPatterns: [String: [NSRegularExpression]] = [
        "csharp": [regex(#"^\s*using\s+(?:static\s+)?(?:[A-Za-z_][A-Za-z0-9_]*\s*=\s*)?([A-Za-z_][A-Za-z0-9_.]*)\s*;"#)],
        "swift": [regex(#"^\s*import\s+(?:class\s+|struct\s+|enum\s+|protocol\s+|func\s+|var\s+)?([A-Za-z_][A-Za-z0-9_.]*)"#)],
        "python": [
            regex(#"^\s*from\s+([A-Za-z_][A-Za-z0-9_.]*)\s+import\b"#),
            regex(#"^\s*import\s+([A-Za-z_][A-Za-z0-9_.]*)"#),
        ],
        "javascript": [
            regex(#"^\s*import(?:.*?\sfrom\s*)?['"]([^'"]+)['"]"#),
            regex(#"^\s*(?:const|let|var).*?require\(\s*['"]([^'"]+)['"]\s*\)"#),
        ],
        "typescript": [
            regex(#"^\s*import(?:.*?\sfrom\s*)?['"]([^'"]+)['"]"#),
            regex(#"^\s*(?:const|let|var).*?require\(\s*['"]([^'"]+)['"]\s*\)"#),
        ],
        "java": [regex(#"^\s*import\s+(?:static\s+)?([A-Za-z_][A-Za-z0-9_.*]*)\s*;"#)],
        "kotlin": [regex(#"^\s*import\s+([A-Za-z_][A-Za-z0-9_.*]*)"#)],
        "go": [regex(#"^\s*import\s+(?:[A-Za-z_][A-Za-z0-9_]*\s+)?"([^"]+)""#)],
        "rust": [regex(#"^\s*use\s+([A-Za-z_][A-Za-z0-9_:]*)"#)],
        "ruby": [regex(#"^\s*require(?:_relative)?\s+['"]([^'"]+)['"]"#)],
        "php": [regex(#"^\s*use\s+([A-Za-z_\\][A-Za-z0-9_\\]*)\s*;"#)],
        "c": [regex(#"^\s*#\s*include\s*[<"]([^>"]+)[>"]"#)],
        "cpp": [regex(#"^\s*#\s*include\s*[<"]([^>"]+)[>"]"#)],
    ]

    func supports(relativePath: String) -> Bool {
        let ext = URL(fileURLWithPath: relativePath).pathExtension
        return Self.languages[ext] != nil
    }

    func analyze(
        relativePath: String,
        utf8Content: Data,
        maxSymbols: Int,
        maxImports: Int,
        context: ToolExecutionContext?
    ) throws -> RepositoryFileIntelligence {
        try requireContinue(context)
        let ext = URL(fileURLWithPath: relativePath).pathExtension
        guard let language = Self.languages[ext] else {
            return RepositoryFileIntelligence(
                relativePath: relativePath,
                language: "unknown",
                sizeBytes: Int64(utf8Content.count),
                contentHash: FileVersionService.sha256Tagged(utf8Content),
                symbols: [],
                imports: [],
                supportedLanguage: false
            )
        }
        guard let text = String(data: utf8Content, encoding: .utf8) else {
            return RepositoryFileIntelligence(
                relativePath: relativePath,
                language: language,
                sizeBytes: Int64(utf8Content.count),
                contentHash: FileVersionService.sha256Tagged(utf8Content),
                symbols: [],
                imports: [],
                supportedLanguage: true
            )
        }

        let lines = text.components(separatedBy: .newlines)
        var symbols: [RepositorySymbol] = []
        var imports: [RepositoryImport] = []
        let symbolSpecs = Self.symbolPatterns[language] ?? []
        let importSpecs = Self.importPatterns[language] ?? []

        for (offset, line) in lines.enumerated() {
            try requireContinue(context)
            if symbols.count < maxSymbols {
                for spec in symbolSpecs {
                    if let value = Self.capture(spec.regex, line: line) {
                        symbols.append(RepositorySymbol(name: value, kind: spec.kind, line: offset + 1))
                        if symbols.count >= maxSymbols { break }
                    }
                }
            }
            if imports.count < maxImports {
                for pattern in importSpecs {
                    if let value = Self.capture(pattern, line: line) {
                        imports.append(RepositoryImport(target: value, line: offset + 1))
                        if imports.count >= maxImports { break }
                    }
                }
            }
            if symbols.count >= maxSymbols && imports.count >= maxImports { break }
        }

        symbols.sort {
            if $0.line != $1.line { return $0.line < $1.line }
            return $0.name < $1.name
        }
        imports.sort {
            if $0.line != $1.line { return $0.line < $1.line }
            return $0.target < $1.target
        }
        return RepositoryFileIntelligence(
            relativePath: relativePath,
            language: language,
            sizeBytes: Int64(utf8Content.count),
            contentHash: FileVersionService.sha256Tagged(utf8Content),
            symbols: symbols,
            imports: imports,
            supportedLanguage: true
        )
    }

    private static func symbol(_ pattern: String, _ kind: String) -> SymbolPattern {
        SymbolPattern(regex: regex(pattern), kind: kind)
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [])
    }

    private static func capture(_ regex: NSRegularExpression, line: String) -> String? {
        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges > 1 else { return nil }
        let captured = match.range(at: 1)
        guard captured.location != NSNotFound else { return nil }
        let value = ns.substring(with: captured).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func requireContinue(_ context: ToolExecutionContext?) throws {
        guard let context else { return }
        guard context.tryContinue() else {
            throw MCPServerError.operationFailed("Repository intelligence indexing cancelled")
        }
    }
}

final class RepositoryIntelligenceService {
    private static let schemaVersion = "1.0.0"
    private static let maxGitSafetyOutputBytes = 2_000_000

    typealias GitRepoResolver = (String) throws -> URL
    typealias GitRunner = (URL, [String], Int, Bool) throws -> String
    typealias SourceStateCapture = (String) throws -> [String: Any]

    private let resolver: SafePathResolver
    private let gitRepo: GitRepoResolver
    private let runGit: GitRunner
    private let captureSourceState: SourceStateCapture

    init(
        resolver: SafePathResolver,
        gitRepo: @escaping GitRepoResolver,
        runGit: @escaping GitRunner,
        captureSourceState: @escaping SourceStateCapture
    ) {
        self.resolver = resolver
        self.gitRepo = gitRepo
        self.runGit = runGit
        self.captureSourceState = captureSourceState
    }

    func capture(
        repoPath: String,
        options: RepositoryIntelligenceOptions = RepositoryIntelligenceOptions(),
        context: ToolExecutionContext? = nil,
        provider: RepositoryIntelligenceProvider = LexicalSymbolProvider()
    ) throws -> [String: Any] {
        try Self.validate(options)
        if let context, !context.tryContinue() {
            return cancelled(provider: provider, reason: context.truncationReason == "none" ? "cancelled" : context.truncationReason)
        }

        let repo = try gitRepo(repoPath)
        let sourceState = try captureSourceState(repoPath)
        guard let sourceStateID = sourceState["source_state_id"] as? String, !sourceStateID.isEmpty else {
            throw MCPServerError.operationFailed("Repository intelligence SourceStateRef identity is unavailable")
        }
        let cache = try RepositoryIntelligenceCache(
            repo: repo,
            workspaceRoot: resolver.root,
            options: options
        )

        let loaded = cache.tryLoad(
            sourceStateID: sourceStateID,
            provider: provider
        )
        if var cached = loaded.snapshot {
            cached["cache_status"] = "hit"
            cached["cache_recovery"] = loaded.recovery
            return cached
        }

        options.stageForTests?("before_inventory")
        if let context, !context.tryContinue() {
            return cancelled(provider: provider, reason: context.truncationReason == "none" ? "cancelled" : context.truncationReason)
        }

        let inventoryRaw = try runGit(
            repo,
            ["ls-files", "--cached", "-z", "--"],
            Self.maxGitSafetyOutputBytes,
            false
        )
        let tracked = Set(
            inventoryRaw.split(separator: "\0", omittingEmptySubsequences: true)
                .compactMap { Self.normalizeInventoryPath(String($0)) }
        ).sorted()

        var files: [RepositoryFileIntelligence] = []
        var skippedIgnored = 0
        var skippedBinary = 0
        var skippedOversized = 0
        var skippedMissing = 0
        var truncated = false
        var truncationReason = "none"
        var aggregateReadBytes: Int64 = 0
        var visited = 0

        for relative in tracked {
            if let context, !context.tryContinue() {
                truncated = true
                truncationReason = context.truncationReason == "none" ? "cancelled" : context.truncationReason
                break
            }
            if visited >= options.maxTrackedFiles {
                truncated = true
                truncationReason = "max_tracked_files"
                break
            }
            visited += 1
            if let context, !context.tryVisitEntry() {
                truncated = true
                truncationReason = context.truncationReason
                break
            }

            if Self.shouldIgnore(relative) {
                skippedIgnored += 1
                continue
            }
            if Self.binaryExtensions.contains(URL(fileURLWithPath: relative).pathExtension.lowercased()) {
                skippedBinary += 1
                continue
            }

            let absolute = repo.appendingPathComponent(relative).standardizedFileURL
            let sharedRelative = try sharedRelativePath(for: absolute)
            let target = try resolver.resolve(sharedRelative)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                skippedMissing += 1
                continue
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
            if size < 0 || size > Int64(options.maxFileBytes) {
                skippedOversized += 1
                continue
            }

            if !provider.supports(relativePath: relative) {
                files.append(RepositoryFileIntelligence(
                    relativePath: relative,
                    language: "unknown",
                    sizeBytes: size,
                    contentHash: "unread",
                    symbols: [],
                    imports: [],
                    supportedLanguage: false
                ))
                continue
            }

            if size > options.maxAggregateSourceBytes - aggregateReadBytes {
                truncated = true
                truncationReason = "max_aggregate_source_bytes"
                break
            }
            if let context, !context.tryScanFile(bytes: size) {
                truncated = true
                truncationReason = context.truncationReason
                break
            }

            let data = try Self.readFile(target, expectedSize: size)
            aggregateReadBytes += Int64(data.count)
            if Self.looksBinary(data) {
                skippedBinary += 1
                continue
            }
            files.append(try provider.analyze(
                relativePath: relative,
                utf8Content: data,
                maxSymbols: options.maxSymbolsPerFile,
                maxImports: options.maxImportsPerFile,
                context: context
            ))
        }

        let relationResult = Self.buildRelations(files: files, maxRelations: options.maxRelations)
        if relationResult.truncated && !truncated {
            truncated = true
            truncationReason = "max_relations"
        }

        options.stageForTests?("before_source_state_recheck")
        if let context, !context.tryContinue() {
            truncated = true
            truncationReason = context.truncationReason == "none" ? "cancelled" : context.truncationReason
        }
        let after = try captureSourceState(repoPath)
        guard let afterID = after["source_state_id"] as? String, !afterID.isEmpty else {
            throw MCPServerError.operationFailed("Repository intelligence post-index SourceStateRef identity is unavailable")
        }
        guard afterID == sourceStateID else {
            options.stageForTests?("source_state_changed")
            throw MCPServerError.operationFailed("Repository changed while intelligence index was being built")
        }

        var snapshot = Self.snapshot(
            sourceState: after,
            sourceStateID: afterID,
            provider: provider,
            files: files,
            relations: relationResult.relations,
            trackedCount: tracked.count,
            visited: visited,
            aggregateReadBytes: aggregateReadBytes,
            skippedIgnored: skippedIgnored,
            skippedBinary: skippedBinary,
            skippedOversized: skippedOversized,
            skippedMissing: skippedMissing,
            truncated: truncated,
            truncationReason: truncationReason
        )
        snapshot["cache_status"] = "rebuilt"
        snapshot["cache_recovery"] = loaded.recovery

        if !truncated {
            options.stageForTests?("before_cache_write")
            try cache.save(snapshot)
        }
        return snapshot
    }

    private func sharedRelativePath(for url: URL) throws -> String {
        let root = resolver.root.path
        let path = url.standardizedFileURL.path
        guard path != root, path.hasPrefix(root + "/") else {
            throw MCPServerError.invalidPath("Repository intelligence path is outside the shared root")
        }
        return String(path.dropFirst(root.count + 1))
    }

    private func cancelled(provider: RepositoryIntelligenceProvider, reason: String) -> [String: Any] {
        [
            "schema_version": Self.schemaVersion,
            "provider_id": provider.providerID,
            "provider_version": provider.providerVersion,
            "completeness": provider.completeness,
            "parser_profile_hash": provider.parserProfileHash,
            "source_state_id": NSNull(),
            "grants_authority": false,
            "raw_source_persisted": false,
            "cache_status": "not_checked",
            "cache_recovery": "none",
            "tracked_inventory_count": 0,
            "visited_count": 0,
            "indexed_file_count": 0,
            "relation_count": 0,
            "aggregate_source_bytes": 0,
            "truncated": true,
            "truncation_reason": reason,
            "files": [],
            "relations": [],
        ]
    }

    private static func snapshot(
        sourceState: [String: Any],
        sourceStateID: String,
        provider: RepositoryIntelligenceProvider,
        files: [RepositoryFileIntelligence],
        relations: [RepositoryRelation],
        trackedCount: Int,
        visited: Int,
        aggregateReadBytes: Int64,
        skippedIgnored: Int,
        skippedBinary: Int,
        skippedOversized: Int,
        skippedMissing: Int,
        truncated: Bool,
        truncationReason: String
    ) -> [String: Any] {
        let fileValues: [[String: Any]] = files.sorted { $0.relativePath < $1.relativePath }.map { file in
            [
                "path": file.relativePath,
                "language": file.language,
                "size_bytes": file.sizeBytes,
                "content_hash": file.contentHash,
                "supported_language": file.supportedLanguage,
                "symbols": file.symbols.map { ["name": $0.name, "kind": $0.kind, "line": $0.line] },
                "imports": file.imports.map { ["target": $0.target, "line": $0.line] },
            ]
        }
        let relationValues: [[String: Any]] = relations.map {
            [
                "source": $0.source,
                "target": $0.target,
                "kind": $0.kind,
                "score": $0.score,
                "rank": $0.rank,
            ]
        }
        return [
            "schema_version": Self.schemaVersion,
            "provider_id": provider.providerID,
            "provider_version": provider.providerVersion,
            "completeness": provider.completeness,
            "parser_profile_hash": provider.parserProfileHash,
            "source_state_provider_version": sourceState["provider_version"] ?? NSNull(),
            "grants_authority": false,
            "raw_source_persisted": false,
            "source_state_id": sourceStateID,
            "tracked_inventory_count": trackedCount,
            "visited_count": visited,
            "indexed_file_count": files.count,
            "relation_count": relations.count,
            "aggregate_source_bytes": aggregateReadBytes,
            "skipped_ignored": skippedIgnored,
            "skipped_binary": skippedBinary,
            "skipped_oversized": skippedOversized,
            "skipped_missing": skippedMissing,
            "truncated": truncated,
            "truncation_reason": truncationReason,
            "files": fileValues,
            "relations": relationValues,
        ]
    }

    private static let ignoredDirectories: Set<String> = [
        ".git", ".hg", ".svn", ".venv", "venv", "node_modules", "__pycache__",
        "build", "dist", "out", "target", "coverage", ".next", ".turbo", "vendor",
        "generated", "gen", "DerivedData", "Pods",
    ]

    private static let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "pdf", "zip", "gz", "tar", "7z",
        "rar", "exe", "dll", "so", "dylib", "a", "lib", "pdb", "woff", "woff2", "ttf", "otf",
        "mp3", "wav", "mp4", "mov", "avi", "sqlite", "sqlite3", "db", "bin", "class", "jar", "wasm",
    ]

    private static func normalizeInventoryPath(_ raw: String) -> String? {
        let path = raw.replacingOccurrences(of: "\\", with: "/").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !path.hasPrefix("/") else { return nil }
        let segments = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !segments.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { return nil }
        return segments.joined(separator: "/")
    }

    private static func shouldIgnore(_ relativePath: String) -> Bool {
        let segments = relativePath.split(separator: "/").map(String.init)
        if segments.contains(where: { ignoredDirectories.contains($0) }) { return true }
        guard let name = segments.last else { return false }
        let lower = name.lowercased()
        return lower.hasSuffix(".g.cs") ||
            lower.hasSuffix(".generated.cs") ||
            lower.hasSuffix(".designer.cs") ||
            lower.hasSuffix(".min.js") ||
            lower.hasSuffix(".map")
    }

    private static func looksBinary(_ data: Data) -> Bool {
        data.prefix(8192).contains(0)
    }

    private static func readFile(_ url: URL, expectedSize: Int64) throws -> Data {
        guard expectedSize >= 0, expectedSize <= Int64(Int.max) else {
            throw MCPServerError.operationFailed("Repository intelligence file is too large")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var output = Data()
        while output.count < Int(expectedSize) {
            let remaining = Int(expectedSize) - output.count
            guard let chunk = try handle.read(upToCount: min(64 * 1024, remaining)), !chunk.isEmpty else { break }
            output.append(chunk)
        }
        guard output.count == Int(expectedSize) else {
            throw MCPServerError.operationFailed("Repository intelligence source changed while being read")
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let after = (attrs[.size] as? NSNumber)?.int64Value ?? -1
        guard after == expectedSize else {
            throw MCPServerError.operationFailed("Repository intelligence source changed while being read")
        }
        return output
    }

    private static func buildRelations(
        files: [RepositoryFileIntelligence],
        maxRelations: Int
    ) -> (relations: [RepositoryRelation], truncated: Bool) {
        var candidates: [(String, String, String, Double)] = []
        let exact = Dictionary(uniqueKeysWithValues: files.map { ($0.relativePath, $0) })
        let byStem = Dictionary(grouping: files, by: { URL(fileURLWithPath: $0.relativePath).deletingPathExtension().lastPathComponent })
            .mapValues { $0.map(\.relativePath).sorted() }
        let symbolOwners = Dictionary(grouping: files.flatMap { file in file.symbols.map { ($0.name, file.relativePath) } }, by: { $0.0 })
            .mapValues { Array(Set($0.map { $0.1 })).sorted() }
        let byDirectory = Dictionary(grouping: files, by: {
            URL(fileURLWithPath: $0.relativePath).deletingLastPathComponent().path == "."
                ? ""
                : URL(fileURLWithPath: $0.relativePath).deletingLastPathComponent().path
        }).mapValues { $0.map(\.relativePath).sorted() }

        for file in files.sorted(by: { $0.relativePath < $1.relativePath }) {
            if !file.supportedLanguage {
                let directory = URL(fileURLWithPath: file.relativePath).deletingLastPathComponent().path == "."
                    ? ""
                    : URL(fileURLWithPath: file.relativePath).deletingLastPathComponent().path
                for peer in (byDirectory[directory] ?? []).filter({ $0 != file.relativePath }).prefix(4) {
                    candidates.append((file.relativePath, peer, "file_level", 0.10))
                }
            }
            for imported in file.imports {
                if let resolved = resolveImport(
                    sourcePath: file.relativePath,
                    importTarget: imported.target,
                    exact: exact,
                    byStem: byStem,
                    symbolOwners: symbolOwners
                ), resolved.0 != file.relativePath {
                    candidates.append((file.relativePath, resolved.0, resolved.1, resolved.2))
                }
            }
        }

        var seen = Set<String>()
        let ordered = candidates.filter { item in
            let key = "\(item.0)\u{0}\(item.1)\u{0}\(item.2)\u{0}\(item.3)"
            return seen.insert(key).inserted
        }.sorted {
            if $0.3 != $1.3 { return $0.3 > $1.3 }
            if $0.0 != $1.0 { return $0.0 < $1.0 }
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            return $0.2 < $1.2
        }
        let truncated = ordered.count > maxRelations
        let selected = Array(ordered.prefix(maxRelations))
        return (
            selected.enumerated().map {
                RepositoryRelation(source: $0.element.0, target: $0.element.1, kind: $0.element.2, score: $0.element.3, rank: $0.offset + 1)
            },
            truncated
        )
    }

    private static func resolveImport(
        sourcePath: String,
        importTarget: String,
        exact: [String: RepositoryFileIntelligence],
        byStem: [String: [String]],
        symbolOwners: [String: [String]]
    ) -> (String, String, Double)? {
        let normalized = importTarget.replacingOccurrences(of: "\\", with: "/").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if normalized.hasPrefix("./") || normalized.hasPrefix("../") {
            let sourceDir = URL(fileURLWithPath: sourcePath).deletingLastPathComponent()
            let combined = sourceDir.appendingPathComponent(normalized).standardized.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            for candidate in candidateModulePaths(combined) {
                if exact[candidate] != nil { return (candidate, "import", 1.0) }
            }
        }

        let separators = CharacterSet(charactersIn: "/.:")
        let last = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/*"))
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
            .last
        guard let last else { return nil }
        if let values = byStem[last], values.count == 1 { return (values[0], "import_name", 0.75) }
        if let values = symbolOwners[last], values.count == 1 { return (values[0], "symbol_reference", 0.55) }
        return nil
    }

    private static func candidateModulePaths(_ path: String) -> [String] {
        if URL(fileURLWithPath: path).pathExtension.isEmpty {
            let extensions = ["cs", "swift", "py", "js", "jsx", "ts", "tsx", "java", "kt", "go", "rs", "rb", "php", "c", "cc", "cpp", "h", "hpp"]
            var values = [path]
            values += extensions.map { path + "." + $0 }
            values += ["js", "ts", "tsx", "py"].map { path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/index." + $0 }
            return values
        }
        return [path]
    }

    private static func validate(_ options: RepositoryIntelligenceOptions) throws {
        guard (1...100_000).contains(options.maxTrackedFiles),
              (1...500_000_000).contains(options.maxAggregateSourceBytes),
              (1...10_000_000).contains(options.maxFileBytes),
              (1...4096).contains(options.maxSymbolsPerFile),
              (1...4096).contains(options.maxImportsPerFile),
              (1...100_000).contains(options.maxRelations) else {
            throw MCPServerError.invalidArguments("Repository intelligence options are invalid")
        }
    }

    private final class RepositoryIntelligenceCache {
        private let fileURL: URL
        private let options: RepositoryIntelligenceOptions

        init(repo: URL, workspaceRoot: URL, options: RepositoryIntelligenceOptions) throws {
            let base: URL
            if let configured = options.cacheRootURL {
                base = configured.standardizedFileURL
            } else {
                let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
                base = support.appendingPathComponent("FileMCP/repo-intelligence-v1", isDirectory: true).standardizedFileURL
            }
            guard !Self.sameOrDescendant(base, parent: workspaceRoot) else {
                throw MCPServerError.invalidPath("Repository intelligence cache root must be outside the workspace/repository")
            }
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int16(0o700))], ofItemAtPath: base.path)
            let key = String(FileVersionService.sha256Tagged(repo.path).dropFirst("sha256:".count))
            self.fileURL = base.appendingPathComponent(key + ".json")
            self.options = options
        }

        func tryLoad(
            sourceStateID: String,
            provider: RepositoryIntelligenceProvider
        ) -> (snapshot: [String: Any]?, recovery: String) {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return (nil, "none") }
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let size = (attrs[.size] as? NSNumber)?.int64Value ?? -1
                guard size > 0, size <= 64 * 1024 * 1024 else {
                    throw MCPServerError.operationFailed("Repository intelligence cache size is invalid")
                }
                let data = try Data(contentsOf: fileURL)
                guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw MCPServerError.operationFailed("Repository intelligence cache root must be an object")
                }
                try Self.validateShape(parsed)
                let stale =
                    parsed["source_state_id"] as? String != sourceStateID ||
                    parsed["provider_id"] as? String != provider.providerID ||
                    parsed["provider_version"] as? String != provider.providerVersion ||
                    parsed["completeness"] as? String != provider.completeness ||
                    parsed["parser_profile_hash"] as? String != provider.parserProfileHash
                if stale {
                    options.stageForTests?("cache_stale")
                    try? FileManager.default.removeItem(at: fileURL)
                    return (nil, "stale_deleted")
                }
                options.stageForTests?("cache_hit")
                return (parsed, "none")
            } catch {
                options.stageForTests?("cache_corrupt")
                try? FileManager.default.removeItem(at: fileURL)
                return (nil, "corrupt_deleted")
            }
        }

        func save(_ snapshot: [String: Any]) throws {
            var persisted = snapshot
            persisted.removeValue(forKey: "cache_status")
            persisted.removeValue(forKey: "cache_recovery")
            guard JSONSerialization.isValidJSONObject(persisted) else {
                throw MCPServerError.operationFailed("Repository intelligence cache metadata is not serializable")
            }
            let data = try JSONSerialization.data(withJSONObject: persisted, options: [.sortedKeys])
            guard data.count <= 64 * 1024 * 1024 else {
                throw MCPServerError.operationFailed("Repository intelligence cache metadata is too large")
            }
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let temp = directory.appendingPathComponent(".tmp_" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: temp) }
            try data.write(to: temp, options: [])
            try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int16(0o600))], ofItemAtPath: temp.path)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temp)
            } else {
                try FileManager.default.moveItem(at: temp, to: fileURL)
            }
        }

        private static func validateShape(_ parsed: [String: Any]) throws {
            guard parsed["schema_version"] as? String == RepositoryIntelligenceService.schemaVersion else {
                throw MCPServerError.operationFailed("Repository intelligence cache schema mismatch")
            }
            for key in ["provider_id", "provider_version", "completeness", "parser_profile_hash", "source_state_id"] {
                guard let value = parsed[key] as? String, !value.isEmpty else {
                    throw MCPServerError.operationFailed("Repository intelligence cache metadata is incomplete")
                }
            }
            guard parsed["files"] is [[String: Any]], parsed["relations"] is [[String: Any]] else {
                throw MCPServerError.operationFailed("Repository intelligence cache collections are invalid")
            }
        }

        private static func sameOrDescendant(_ candidate: URL, parent: URL) -> Bool {
            let child = candidate.standardizedFileURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let root = parent.standardizedFileURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return child == root || child.hasPrefix(root + "/")
        }
    }
}
