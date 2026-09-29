import Foundation
import CryptoKit

struct RepositoryIntelligenceSymbol: Codable, Equatable {
    let name: String
    let kind: String
    let file: String
    let line: Int
}

struct RepositoryIntelligenceFile: Codable, Equatable {
    let path: String
    let language: String
    let sizeBytes: Int64
    let symbols: [RepositoryIntelligenceSymbol]
    let imports: [String]

    enum CodingKeys: String, CodingKey {
        case path, language, symbols, imports
        case sizeBytes = "size_bytes"
    }
}

struct RepositoryIntelligenceRelation: Codable, Equatable {
    let source: String
    let target: String
    let reason: String
    let score: Double
}

struct RepositoryIntelligenceSnapshot: Codable {
    let providerID: String
    let providerVersion: String
    let completeness: String
    let sourceStateID: String
    let generationID: String
    let builtEpochMs: Int64
    let files: [RepositoryIntelligenceFile]
    let relations: [RepositoryIntelligenceRelation]
    var cacheHit: Bool

    enum CodingKeys: String, CodingKey {
        case completeness, files, relations
        case providerID = "provider_id"
        case providerVersion = "provider_version"
        case sourceStateID = "source_state_id"
        case generationID = "generation_id"
        case builtEpochMs = "built_epoch_ms"
        case cacheHit = "cache_hit"
    }

    func metadata() -> [String: Any] {
        [
            "provider_id": providerID,
            "provider_version": providerVersion,
            "completeness": completeness,
            "source_state_id": sourceStateID,
            "generation_id": generationID,
            "built_epoch_ms": builtEpochMs,
            "file_count": files.count,
            "relation_count": relations.count,
            "cache_hit": cacheHit,
        ]
    }
}

struct RepositoryIntelligenceInventoryFile {
    let relativePath: String
    let absoluteURL: URL
    let sizeBytes: Int64
}

struct RepositoryIntelligenceBuildContext {
    let files: [RepositoryIntelligenceInventoryFile]
    let executionContext: ToolExecutionContext?
}

struct RepositoryIntelligenceProviderResult {
    let files: [RepositoryIntelligenceFile]
    let relations: [RepositoryIntelligenceRelation]
}

protocol RepositoryIntelligenceProvider {
    var providerID: String { get }
    var providerVersion: String { get }
    var completeness: String { get }
    func build(context: RepositoryIntelligenceBuildContext) throws -> RepositoryIntelligenceProviderResult
}

enum RepositoryIntelligenceError: LocalizedError {
    case invalid(String)
    case cancelledOrBudget(String)

    var errorDescription: String? {
        switch self {
        case let .invalid(message), let .cancelledOrBudget(message):
            return message
        }
    }
}

final class LexicalSymbolProvider: RepositoryIntelligenceProvider {
    static let id = "lexical"
    static let version = "lexical-v1"
    static let heuristicCompleteness = "heuristic"
    static let maxFileBytes: Int64 = 512 * 1024
    static let maxAggregateBytes: Int64 = 20 * 1024 * 1024

    let providerID = id
    let providerVersion = version
    let completeness = heuristicCompleteness

    private static let csharpSymbol = try! NSRegularExpression(
        pattern: #"^\s*(?:(?:public|internal|private|protected|static|sealed|abstract|partial|async|virtual|override|readonly)\s+)*(?<kind>class|interface|record|struct|enum|namespace)\s+(?<name>[A-Za-z_][A-Za-z0-9_.]*)"#
    )
    private static let csharpMethod = try! NSRegularExpression(
        pattern: #"^\s*(?:(?:public|internal|private|protected|static|async|virtual|override|sealed|partial|extern|unsafe)\s+)+[A-Za-z_][A-Za-z0-9_<>,?\[\].\s]*\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*\("#
    )
    private static let swiftSymbol = try! NSRegularExpression(
        pattern: #"^\s*(?:(?:public|internal|private|fileprivate|open|final|static|class|actor|nonisolated|@\w+)\s+)*(?<kind>class|struct|enum|protocol|actor|func)\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)"#
    )
    private static let pythonSymbol = try! NSRegularExpression(
        pattern: #"^\s*(?<kind>class|def|async\s+def)\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)"#
    )
    private static let jsSymbol = try! NSRegularExpression(
        pattern: #"^\s*(?:(?:export|default|async|declare)\s+)*(?<kind>class|function|interface|type|enum)\s+(?<name>[A-Za-z_$][A-Za-z0-9_$]*)"#
    )
    private static let jsBinding = try! NSRegularExpression(
        pattern: #"^\s*(?:(?:export|default)\s+)?(?:const|let|var)\s+(?<name>[A-Za-z_$][A-Za-z0-9_$]*)\s*="#
    )

    func build(context: RepositoryIntelligenceBuildContext) throws -> RepositoryIntelligenceProviderResult {
        var files: [RepositoryIntelligenceFile] = []
        var aggregate: Int64 = 0

        for entry in context.files {
            try requireContinue(context.executionContext, stage: "provider inventory")
            let language = Self.language(for: entry.relativePath)
            if language == "unknown" {
                files.append(RepositoryIntelligenceFile(
                    path: entry.relativePath,
                    language: language,
                    sizeBytes: entry.sizeBytes,
                    symbols: [],
                    imports: []
                ))
                continue
            }

            if entry.sizeBytes > Self.maxFileBytes || aggregate > Self.maxAggregateBytes - entry.sizeBytes {
                files.append(RepositoryIntelligenceFile(
                    path: entry.relativePath,
                    language: language,
                    sizeBytes: entry.sizeBytes,
                    symbols: [],
                    imports: []
                ))
                continue
            }
            if let executionContext = context.executionContext,
               !executionContext.tryScanFile(bytes: entry.sizeBytes) {
                throw RepositoryIntelligenceError.cancelledOrBudget(
                    "Repository intelligence indexing stopped by ToolBudget: \(executionContext.truncationReason)"
                )
            }

            let data = try Data(contentsOf: entry.absoluteURL, options: [.mappedIfSafe])
            guard let text = String(data: data, encoding: .utf8) else {
                files.append(RepositoryIntelligenceFile(
                    path: entry.relativePath,
                    language: "binary_or_non_utf8",
                    sizeBytes: entry.sizeBytes,
                    symbols: [],
                    imports: []
                ))
                continue
            }
            aggregate += entry.sizeBytes

            var symbols: [RepositoryIntelligenceSymbol] = []
            var imports = Set<String>()
            let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            for (offset, line) in normalized.components(separatedBy: "\n").enumerated() {
                try requireContinue(context.executionContext, stage: "symbol extraction")
                Self.extract(
                    language: language,
                    path: entry.relativePath,
                    lineNumber: offset + 1,
                    line: line,
                    symbols: &symbols,
                    imports: &imports
                )
            }

            files.append(RepositoryIntelligenceFile(
                path: entry.relativePath,
                language: language,
                sizeBytes: entry.sizeBytes,
                symbols: symbols,
                imports: imports.sorted()
            ))
        }

        return RepositoryIntelligenceProviderResult(files: files, relations: Self.buildRelations(files))
    }

    private static func requireContinue(_ context: ToolExecutionContext?, stage: String) throws {
        guard let context else { return }
        guard context.tryContinue() else {
            throw RepositoryIntelligenceError.cancelledOrBudget(
                "Repository intelligence \(stage) stopped: \(context.truncationReason)"
            )
        }
    }

    private static func language(for path: String) -> String {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "cs": return "csharp"
        case "swift": return "swift"
        case "py": return "python"
        case "js", "jsx", "mjs", "cjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "json", "md", "yml", "yaml", "toml", "xml", "props", "targets": return "data"
        default: return "unknown"
        }
    }

    private static func extract(
        language: String,
        path: String,
        lineNumber: Int,
        line: String,
        symbols: inout [RepositoryIntelligenceSymbol],
        imports: inout Set<String>
    ) {
        var match: NSTextCheckingResult?
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        switch language {
        case "csharp":
            match = firstMatch(csharpSymbol, line)
            if match == nil { match = firstMatch(csharpMethod, line) }
            if trimmed.hasPrefix("using ") {
                var value = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                if value.hasSuffix(";") { value.removeLast() }
                if let equals = value.firstIndex(of: "=") {
                    value = String(value[value.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
                }
                if !value.isEmpty { imports.insert(value) }
            }
        case "swift":
            match = firstMatch(swiftSymbol, line)
            if trimmed.hasPrefix("import ") {
                let value = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { imports.insert(value) }
            }
        case "python":
            match = firstMatch(pythonSymbol, line)
            if trimmed.hasPrefix("import ") {
                for raw in trimmed.dropFirst(7).split(separator: ",") {
                    let value = raw.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
                    if !value.isEmpty { imports.insert(value) }
                }
            } else if trimmed.hasPrefix("from ") {
                let value = trimmed.dropFirst(5).split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
                if !value.isEmpty { imports.insert(value) }
            }
        case "javascript", "typescript":
            match = firstMatch(jsSymbol, line)
            if match == nil { match = firstMatch(jsBinding, line) }
            if let range = trimmed.range(of: " from ", options: .backwards) {
                addQuotedImport(String(trimmed[range.upperBound...]), imports: &imports)
            } else if trimmed.hasPrefix("import ") {
                addQuotedImport(String(trimmed.dropFirst(7)), imports: &imports)
            }
            if let range = trimmed.range(of: "require(") {
                addQuotedImport(String(trimmed[range.upperBound...]), imports: &imports)
            }
        default:
            break
        }

        guard symbols.count < 2048, let match else { return }
        let nsLine = line as NSString
        let nameRange = match.range(withName: "name")
        guard nameRange.location != NSNotFound else { return }
        let name = nsLine.substring(with: nameRange)
        guard !name.isEmpty else { return }
        let kindRange = match.range(withName: "kind")
        let kind = kindRange.location == NSNotFound
            ? "binding"
            : nsLine.substring(with: kindRange).replacingOccurrences(of: " ", with: "_")
        symbols.append(RepositoryIntelligenceSymbol(name: name, kind: kind, file: path, line: lineNumber))
    }

    private static func firstMatch(_ regex: NSRegularExpression, _ line: String) -> NSTextCheckingResult? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.firstMatch(in: line, range: range)
    }

    private static func addQuotedImport(_ value: String, imports: inout Set<String>) {
        guard let start = value.firstIndex(where: { $0 == "'" || $0 == "\"" }) else { return }
        let quote = value[start]
        let rest = value[value.index(after: start)...]
        guard let end = rest.firstIndex(of: quote) else { return }
        let imported = String(rest[..<end])
        if !imported.isEmpty { imports.insert(imported) }
    }

    private static func buildRelations(_ files: [RepositoryIntelligenceFile]) -> [RepositoryIntelligenceRelation] {
        var byStem: [String: [String]] = [:]
        for file in files {
            let stem = URL(fileURLWithPath: file.path).deletingPathExtension().lastPathComponent.lowercased()
            byStem[stem, default: []].append(file.path)
        }

        var result: [RepositoryIntelligenceRelation] = []
        for file in files {
            var targets: [String: (reason: String, score: Double)] = [:]
            for imported in file.imports {
                let normalized = imported.replacingOccurrences(of: "\\", with: "/")
                let last = normalized.split(separator: "/").last.map(String.init) ?? normalized
                let stem = URL(fileURLWithPath: last).deletingPathExtension().lastPathComponent.lowercased()
                guard !stem.isEmpty, let candidates = byStem[stem] else { continue }
                for candidate in candidates where candidate != file.path {
                    targets[candidate] = ("import", 1.0)
                }
            }

            let directory = (file.path as NSString).deletingLastPathComponent.lowercased()
            for candidate in files where candidate.path != file.path {
                let candidateDirectory = (candidate.path as NSString).deletingLastPathComponent.lowercased()
                if candidateDirectory == directory, targets[candidate.path] == nil {
                    targets[candidate.path] = ("same_directory", 0.25)
                }
            }

            let ranked = targets.map { key, value in
                RepositoryIntelligenceRelation(source: file.path, target: key, reason: value.reason, score: value.score)
            }.sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.target < $1.target
            }
            result.append(contentsOf: ranked.prefix(128))
        }
        return result
    }
}

final class RepositoryIntelligenceService {
    static let cacheSchemaVersion = "1"
    static let maxTrackedFiles = 20_000

    private static let ignoredSegments: Set<String> = [
        ".git", ".svn", ".hg", "node_modules", ".venv", "venv", "__pycache__",
        "bin", "obj", "dist", "build", "coverage", ".next", ".turbo", "vendor",
    ]

    private let workspaceRoot: URL
    private let containsWorkspaceURL: (URL) -> Bool
    private let gitRepo: (String) throws -> URL
    private let listTracked: (URL) throws -> String
    private let captureSourceState: (String) throws -> [String: Any]
    private let provider: any RepositoryIntelligenceProvider
    private let cacheRoot: URL?

    var cacheRootForTest: URL? { cacheRoot }

    init(
        workspaceRoot: URL,
        containsWorkspaceURL: @escaping (URL) -> Bool,
        gitRepo: @escaping (String) throws -> URL,
        listTracked: @escaping (URL) throws -> String,
        captureSourceState: @escaping (String) throws -> [String: Any],
        provider: (any RepositoryIntelligenceProvider)? = nil,
        cacheRoot: URL? = nil
    ) throws {
        self.workspaceRoot = workspaceRoot.standardizedFileURL
        self.containsWorkspaceURL = containsWorkspaceURL
        self.gitRepo = gitRepo
        self.listTracked = listTracked
        self.captureSourceState = captureSourceState
        self.provider = provider ?? LexicalSymbolProvider()

        if let cacheRoot {
            let explicit = cacheRoot.standardizedFileURL
            guard !Self.isWithinWorkspace(explicit, workspace: self.workspaceRoot) else {
                throw RepositoryIntelligenceError.invalid("Repository intelligence cache must be outside the workspace")
            }
            self.cacheRoot = explicit
        } else {
            self.cacheRoot = Self.selectDefaultCacheRoot(workspace: self.workspaceRoot)
        }
    }

    func getOrBuild(repoPath: String, executionContext: ToolExecutionContext? = nil) throws -> RepositoryIntelligenceSnapshot {
        try requireContinue(executionContext, stage: "start")
        let repo = try gitRepo(repoPath).standardizedFileURL
        let source = try captureSourceState(repoPath)
        guard let sourceStateID = source["source_state_id"] as? String, !sourceStateID.isEmpty else {
            throw RepositoryIntelligenceError.invalid("Repository intelligence requires SourceStateRef identity")
        }

        let cacheURL = cacheURL(repo: repo, sourceStateID: sourceStateID)
        if let cacheURL, let cached = tryLoadCache(cacheURL, sourceStateID: sourceStateID) {
            var hit = cached
            hit.cacheHit = true
            return hit
        }

        let inventoryRaw = try listTracked(repo)
        if inventoryRaw.contains("[...truncated "), inventoryRaw.hasSuffix(" bytes...]") {
            throw RepositoryIntelligenceError.invalid("Repository intelligence Git inventory exceeded the safety scan limit")
        }
        let paths = Array(Set(inventoryRaw.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)
            .map { $0.replacingOccurrences(of: "\\", with: "/") }
            .filter { !Self.isIgnored($0) })).sorted()
        guard paths.count <= Self.maxTrackedFiles else {
            throw RepositoryIntelligenceError.invalid(
                "Repository intelligence tracked inventory exceeds \(Self.maxTrackedFiles) files"
            )
        }

        var files: [RepositoryIntelligenceInventoryFile] = []
        let repoPathValue = repo.path
        for path in paths {
            try requireContinue(executionContext, stage: "inventory")
            if let executionContext, !executionContext.tryVisitEntry() {
                throw RepositoryIntelligenceError.cancelledOrBudget(
                    "Repository intelligence inventory stopped by ToolBudget: \(executionContext.truncationReason)"
                )
            }
            guard !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
                throw RepositoryIntelligenceError.invalid("Repository intelligence inventory contains an invalid path")
            }
            let absolute = repo.appendingPathComponent(path).standardizedFileURL
            guard absolute.path.hasPrefix(repoPathValue + "/"), containsWorkspaceURL(absolute) else {
                throw RepositoryIntelligenceError.invalid("Repository intelligence inventory escaped the repository")
            }
            let values = try absolute.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            if values.isSymbolicLink == true || values.isRegularFile != true { continue }
            files.append(RepositoryIntelligenceInventoryFile(
                relativePath: path,
                absoluteURL: absolute,
                sizeBytes: Int64(values.fileSize ?? 0)
            ))
        }

        let result = try provider.build(context: RepositoryIntelligenceBuildContext(
            files: files,
            executionContext: executionContext
        ))
        try requireContinue(executionContext, stage: "cache publish")
        let snapshot = RepositoryIntelligenceSnapshot(
            providerID: provider.providerID,
            providerVersion: provider.providerVersion,
            completeness: provider.completeness,
            sourceStateID: sourceStateID,
            generationID: Self.computeGeneration(
                providerID: provider.providerID,
                providerVersion: provider.providerVersion,
                completeness: provider.completeness,
                sourceStateID: sourceStateID,
                result: result
            ),
            builtEpochMs: Int64(Date().timeIntervalSince1970 * 1000),
            files: result.files,
            relations: result.relations,
            cacheHit: false
        )
        if let cacheURL {
            do {
                try persistCache(cacheURL, snapshot: snapshot)
                cleanupStaleGenerations(keeping: cacheURL)
            } catch {
                // Cache is a rebuildable optimization and never repository/tool authority.
            }
        }
        return snapshot
    }

    private func cacheURL(repo: URL, sourceStateID: String) -> URL? {
        guard let cacheRoot else { return nil }
        let repoKey = Self.sha256Hex(repo.path)
        let providerKey = Self.sha256Hex(provider.providerID + "\n" + provider.providerVersion)
        let name = sourceStateID.replacingOccurrences(of: ":", with: "_") + ".json"
        return cacheRoot
            .appendingPathComponent(repoKey, isDirectory: true)
            .appendingPathComponent(providerKey, isDirectory: true)
            .appendingPathComponent(name, isDirectory: false)
    }

    private static func selectDefaultCacheRoot(workspace: URL) -> URL? {
        var candidates: [URL] = []
        if let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            candidates.append(
                applicationSupport
                    .appendingPathComponent("FileMCP", isDirectory: true)
                    .appendingPathComponent("repository-intelligence-cache", isDirectory: true)
            )
        }
        candidates.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".filemcp", isDirectory: true)
                .appendingPathComponent("repository-intelligence-cache", isDirectory: true)
        )
        candidates.append(
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("FileMCP", isDirectory: true)
                .appendingPathComponent("repository-intelligence-cache", isDirectory: true)
        )
        for candidate in candidates.map({ $0.standardizedFileURL }) {
            if !isWithinWorkspace(candidate, workspace: workspace) { return candidate }
        }
        return nil
    }

    private static func isWithinWorkspace(_ candidate: URL, workspace: URL) -> Bool {
        let workspacePath = workspace.standardizedFileURL.path
        let candidatePath = candidate.standardizedFileURL.path
        return candidatePath == workspacePath || candidatePath.hasPrefix(workspacePath + "/")
    }

    private func tryLoadCache(_ url: URL, sourceStateID: String) -> RepositoryIntelligenceSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let envelope = try JSONDecoder().decode(CacheEnvelope.self, from: data)
            guard envelope.schemaVersion == Self.cacheSchemaVersion,
                  envelope.snapshot.providerID == provider.providerID,
                  envelope.snapshot.providerVersion == provider.providerVersion,
                  envelope.snapshot.completeness == provider.completeness,
                  envelope.snapshot.sourceStateID == sourceStateID else {
                throw RepositoryIntelligenceError.invalid("Repository intelligence cache identity mismatch")
            }
            return envelope.snapshot
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    private func persistCache(_ url: URL, snapshot: RepositoryIntelligenceSnapshot) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let envelope = CacheEnvelope(schemaVersion: Self.cacheSchemaVersion, snapshot: snapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        try data.write(to: url, options: [.atomic])
    }

    private func cleanupStaleGenerations(keeping url: URL) {
        let directory = url.deletingLastPathComponent()
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for entry in entries where entry.pathExtension == "json" && entry != url {
            try? FileManager.default.removeItem(at: entry)
        }
    }

    private static func isIgnored(_ path: String) -> Bool {
        path.split(separator: "/").contains { ignoredSegments.contains(String($0).lowercased()) }
    }

    private static func computeGeneration(
        providerID: String,
        providerVersion: String,
        completeness: String,
        sourceStateID: String,
        result: RepositoryIntelligenceProviderResult
    ) -> String {
        var components: [String] = [
            providerID, providerVersion, completeness, sourceStateID,
        ]
        for file in result.files.sorted(by: { $0.path < $1.path }) {
            components.append(file.path)
            components.append(file.language)
            components.append(String(file.sizeBytes))
            for symbol in file.symbols {
                components.append("\(symbol.kind):\(symbol.name):\(symbol.line)")
            }
            for imported in file.imports {
                components.append("import:\(imported)")
            }
        }
        for relation in result.relations.sorted(by: {
            if $0.source != $1.source { return $0.source < $1.source }
            return $0.target < $1.target
        }) {
            components.append("\(relation.source)>\(relation.target):\(relation.reason):\(relation.score)")
        }
        return "sha256:" + sha256Hex(components.joined(separator: "\0"))
    }

    private static func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func requireContinue(_ context: ToolExecutionContext?, stage: String) throws {
        guard let context else { return }
        guard context.tryContinue() else {
            throw RepositoryIntelligenceError.cancelledOrBudget(
                "Repository intelligence \(stage) stopped: \(context.truncationReason)"
            )
        }
    }

    private struct CacheEnvelope: Codable {
        let schemaVersion: String
        let snapshot: RepositoryIntelligenceSnapshot

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case snapshot
        }
    }
}
