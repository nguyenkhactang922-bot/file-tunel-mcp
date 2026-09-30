import Foundation
import Darwin

struct WorkspaceCheckpointOptions {
    var metadataRootDirectory: URL?
    var defaultTTL: TimeInterval = 24 * 60 * 60
    var maxTTL: TimeInterval = 7 * 24 * 60 * 60
    var maxEntries = 5_000
    var maxTotalBytes: Int64 = 50_000_000
    var maxSingleFileBytes: Int64 = 32 * 1024 * 1024
    var now: () -> Date = Date.init
    var stageForTests: ((String) -> Void)?
}

final class WorkspaceCheckpointService {
    private static let schemaVersion = 1
    private let resolver: SafePathResolver
    private let artifactFactory: () throws -> ArtifactContentStore
    private let policy: ServerPolicy
    private let options: WorkspaceCheckpointOptions
    private let resolveRepo: (String) throws -> URL
    private let runGit: (URL, [String], Int, Bool) throws -> String
    private let readIndexBlob: (URL, String) throws -> Data?
    private let captureSourceState: (String, [String]) throws -> [String: Any]
    private let workspaceAuthorityID: String
    private let metadataRoot: URL
    private let indexURL: URL
    private let lock = NSLock()
    private var initialized = false
    private var records: [CheckpointRecord] = []

    init(
        resolver: SafePathResolver,
        artifactFactory: @escaping () throws -> ArtifactContentStore,
        policy: ServerPolicy,
        resolveRepo: @escaping (String) throws -> URL,
        runGit: @escaping (URL, [String], Int, Bool) throws -> String,
        readIndexBlob: @escaping (URL, String) throws -> Data?,
        captureSourceState: @escaping (String, [String]) throws -> [String: Any],
        options: WorkspaceCheckpointOptions = WorkspaceCheckpointOptions()
    ) throws {
        try Self.validateOptions(options)
        self.resolver = resolver
        self.artifactFactory = artifactFactory
        self.policy = policy
        self.options = options
        self.resolveRepo = resolveRepo
        self.runGit = runGit
        self.readIndexBlob = readIndexBlob
        self.captureSourceState = captureSourceState
        self.workspaceAuthorityID = ArtifactContentStore.workspaceAuthorityID(resolver.root)

        let base: URL
        if let configured = options.metadataRootDirectory {
            base = configured.standardizedFileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
            base = support.appendingPathComponent("FileMCP/checkpoints-v1", isDirectory: true)
        }
        let suffix = String(self.workspaceAuthorityID.dropFirst("sha256:".count))
        self.metadataRoot = base.appendingPathComponent(suffix, isDirectory: true)
        self.indexURL = self.metadataRoot.appendingPathComponent("index-v1.json", isDirectory: false)
    }

    func capture(
        repoPath: String,
        includeUntracked: Bool,
        includeIgnored: Bool,
        includeGenerated: Bool,
        ttlSeconds: Int,
        maxFiles: Int,
        maxTotalBytes: Int64,
        preparedPolicy: PolicySnapshot,
        executionContext: ToolExecutionContext?
    ) throws -> [String: Any] {
        try requireContinue(executionContext)
        let ttl = try resolveTTL(ttlSeconds)
        let effectiveMaxFiles = maxFiles == 0 ? options.maxEntries : maxFiles
        let effectiveMaxBytes = maxTotalBytes == 0 ? options.maxTotalBytes : maxTotalBytes
        guard effectiveMaxFiles >= 1, effectiveMaxFiles <= options.maxEntries else {
            throw MCPServerError.invalidArguments("max_files must be between 1 and \(options.maxEntries)")
        }
        guard effectiveMaxBytes >= 1, effectiveMaxBytes <= options.maxTotalBytes else {
            throw MCPServerError.invalidArguments("max_total_bytes must be between 1 and \(options.maxTotalBytes)")
        }

        let repo = try resolveRepo(repoPath)
        let sourceBefore = try captureSourceState(repoPath, [])
        let sourceStateID = try requiredString(sourceBefore, "source_state_id")
        let headOID = optionalString(sourceBefore, "head_oid")
        let indexFingerprint = try requiredString(sourceBefore, "index_fingerprint")

        let staged = splitNul(try runGit(
            repo, ["diff", "--cached", "--name-only", "--diff-filter=ACMRD", "-z", "--"],
            8 * 1024 * 1024, false))
        let unstaged = splitNul(try runGit(
            repo, ["diff", "--name-only", "--diff-filter=ACMRD", "-z", "--"],
            8 * 1024 * 1024, false))
        let untracked = includeUntracked
            ? splitNul(try runGit(repo, ["ls-files", "--others", "--exclude-standard", "-z", "--"], 8 * 1024 * 1024, false))
            : []
        let ignored = includeIgnored
            ? splitNul(try runGit(repo, ["ls-files", "--others", "--ignored", "--exclude-standard", "-z", "--"], 8 * 1024 * 1024, false))
            : []

        let stagedSet = Set(staged)
        let unstagedSet = Set(unstaged)
        let untrackedSet = Set(untracked)
        let ignoredSet = Set(ignored)
        let allPaths = Array(stagedSet.union(unstagedSet).union(untrackedSet).union(ignoredSet)).sorted()
        guard allPaths.count <= effectiveMaxFiles else {
            throw MCPServerError.operationFailed("Checkpoint file count exceeds max_files (\(effectiveMaxFiles))")
        }

        let guardBefore = try captureSourceState(repoPath, allPaths)
        let guardStateID = try requiredString(guardBefore, "source_state_id")
        let repoCanonical = repo.standardizedFileURL.path
        let repoPrefix = repoCanonical.hasSuffix("/") ? repoCanonical : repoCanonical + "/"
        var createdRefs: [String] = []
        var entries: [CheckpointManifestEntry] = []
        var totalBytes: Int64 = 0

        do {
            for path in allPaths {
                try requireContinue(executionContext)
                try Self.validateRepoRelativePath(path)
                let lexical = repo.appendingPathComponent(path).standardizedFileURL
                guard lexical.path.hasPrefix(repoPrefix) else {
                    throw MCPServerError.invalidPath("Checkpoint path escaped the repository")
                }

                var st = stat()
                if lstat(lexical.path, &st) == 0, (st.st_mode & S_IFMT) == S_IFLNK {
                    throw MCPServerError.invalidPath("Checkpoint refuses symlink/reparse entry: \(path)")
                }

                let sharedRelative = relativeToWorkspace(lexical)
                let resolved = try resolver.resolve(sharedRelative)
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory)
                if exists, isDirectory.boolValue {
                    throw MCPServerError.invalidArguments("Checkpoint only captures regular files: \(path)")
                }

                let generated = Self.isGeneratedPath(path)
                var indexRef: String?
                var indexHash: String?
                var indexBytes: Int64 = 0
                var indexExcludedReason: String?
                if stagedSet.contains(path) {
                    if generated && !includeGenerated {
                        indexExcludedReason = "generated"
                    } else if let data = try readIndexBlob(repo, path) {
                        if Int64(data.count) > options.maxSingleFileBytes {
                            indexExcludedReason = "oversized"
                        } else {
                            try enforcePayloadBounds(path, Int64(data.count), totalBytes: &totalBytes, maximum: effectiveMaxBytes)
                            let descriptor = try artifactFactory().put(
                                data: data,
                                workspaceAuthorityID: workspaceAuthorityID,
                                contentClass: ArtifactContentClasses.checkpoint,
                                mediaType: "application/octet-stream",
                                ttl: ttl
                            )
                            createdRefs.append(descriptor.contentRef)
                            indexRef = descriptor.contentRef
                            indexHash = descriptor.blobID
                            indexBytes = descriptor.sizeBytes
                        }
                    }
                }

                var worktreeRef: String?
                var worktreeHash: String?
                var worktreeBytes: Int64 = 0
                var worktreeExcludedReason: String?
                if exists && (stagedSet.contains(path) || unstagedSet.contains(path) || untrackedSet.contains(path) || ignoredSet.contains(path)) {
                    let attrs = try FileManager.default.attributesOfItem(atPath: resolved.path)
                    let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                    if generated && !includeGenerated {
                        worktreeExcludedReason = "generated"
                    } else if size > options.maxSingleFileBytes {
                        worktreeExcludedReason = "oversized"
                    } else {
                        try enforcePayloadBounds(path, size, totalBytes: &totalBytes, maximum: effectiveMaxBytes)
                        let data = try Data(contentsOf: resolved, options: [.mappedIfSafe])
                        guard Int64(data.count) == size else {
                            throw MCPServerError.operationFailed("Checkpoint file changed while being read: \(path)")
                        }
                        let descriptor = try artifactFactory().put(
                            data: data,
                            workspaceAuthorityID: workspaceAuthorityID,
                            contentClass: ArtifactContentClasses.checkpoint,
                            mediaType: "application/octet-stream",
                            ttl: ttl
                        )
                        createdRefs.append(descriptor.contentRef)
                        worktreeRef = descriptor.contentRef
                        worktreeHash = descriptor.blobID
                        worktreeBytes = descriptor.sizeBytes
                    }
                }

                entries.append(CheckpointManifestEntry(
                    relativePath: path,
                    staged: stagedSet.contains(path),
                    unstaged: unstagedSet.contains(path),
                    untracked: untrackedSet.contains(path),
                    ignored: ignoredSet.contains(path),
                    generated: generated,
                    worktreeExists: exists,
                    indexContentRef: indexRef,
                    indexSha256: indexHash,
                    indexSizeBytes: indexBytes,
                    indexExcludedReason: indexExcludedReason,
                    worktreeContentRef: worktreeRef,
                    worktreeSha256: worktreeHash,
                    worktreeSizeBytes: worktreeBytes,
                    worktreeExcludedReason: worktreeExcludedReason
                ))
            }

            options.stageForTests?("after_payloads")
            let sourceAfter = try captureSourceState(repoPath, [])
            let guardAfter = try captureSourceState(repoPath, allPaths)
            guard sourceStateID == (try requiredString(sourceAfter, "source_state_id")),
                  guardStateID == (try requiredString(guardAfter, "source_state_id")) else {
                throw MCPServerError.operationFailed("Repository changed while checkpoint capture was in progress")
            }

            try policy.authorize("checkpoint_capture", prepared: preparedPolicy)
            try requireContinue(executionContext)

            let now = options.now()
            let manifest = CheckpointManifest(
                schemaVersion: Self.schemaVersion,
                workspaceAuthorityID: workspaceAuthorityID,
                repositoryRelativePath: relativeToWorkspace(repo),
                headOid: headOID,
                indexFingerprint: indexFingerprint,
                sourceStateId: sourceStateID,
                createdEpochMs: epochMs(now),
                expiresEpochMs: epochMs(now.addingTimeInterval(ttl)),
                includeUntracked: includeUntracked,
                includeIgnored: includeIgnored,
                includeGenerated: includeGenerated,
                stagedCount: entries.filter(\.staged).count,
                unstagedCount: entries.filter(\.unstaged).count,
                untrackedCount: entries.filter(\.untracked).count,
                ignoredCount: entries.filter(\.ignored).count,
                excludedCount: entries.filter { $0.indexExcludedReason != nil || $0.worktreeExcludedReason != nil }.count,
                totalBytes: totalBytes,
                entries: entries
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let manifestData = try encoder.encode(manifest)
            let packaged = try artifactFactory().put(
                data: manifestData,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClass: ArtifactContentClasses.checkpoint,
                mediaType: "application/vnd.filemcp.checkpoint+json",
                ttl: ttl
            )
            createdRefs.append(packaged.contentRef)

            let record = CheckpointRecord(
                checkpointRef: packaged.contentRef,
                manifestHash: packaged.blobID,
                workspaceAuthorityID: workspaceAuthorityID,
                repositoryRelativePath: manifest.repositoryRelativePath,
                headOid: headOID,
                sourceStateId: sourceStateID,
                createdEpochMs: manifest.createdEpochMs,
                expiresEpochMs: manifest.expiresEpochMs,
                entryCount: entries.count,
                totalBytes: totalBytes,
                stagedCount: manifest.stagedCount,
                unstagedCount: manifest.unstagedCount,
                untrackedCount: manifest.untrackedCount,
                ignoredCount: manifest.ignoredCount,
                excludedCount: manifest.excludedCount
            )
            try addRecord(record)
            options.stageForTests?("after_record")
            return recordMetadata(record, manifest: manifest)
        } catch {
            for contentRef in createdRefs.reversed() {
                try? artifactFactory().delete(
                    contentRef,
                    workspaceAuthorityID: workspaceAuthorityID,
                    contentClassAllowed: { $0 == ArtifactContentClasses.checkpoint }
                )
            }
            throw error
        }
    }

    func list(maxItems: Int) throws -> [String: Any] {
        guard (1...1000).contains(maxItems) else {
            throw MCPServerError.invalidArguments("max_items must be between 1 and 1000")
        }
        try initialize()
        try pruneExpired()
        lock.lock()
        let snapshot = Array(records.sorted { $0.createdEpochMs > $1.createdEpochMs }.prefix(maxItems))
        lock.unlock()
        return [
            "items": snapshot.map { recordMetadata($0) },
            "count": snapshot.count,
            "workspace_authority_id": workspaceAuthorityID,
        ]
    }

    func get(checkpointRef: String) throws -> [String: Any] {
        guard !checkpointRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MCPServerError.invalidArguments("checkpoint_ref must be non-empty")
        }
        try initialize()
        try pruneExpired()
        lock.lock()
        let record = records.first { $0.checkpointRef == checkpointRef }
        lock.unlock()
        guard let record else { throw MCPServerError.notFound("Unknown or expired checkpoint_ref") }
        let manifest = try loadManifest(record)
        return recordMetadata(record, manifest: manifest)
    }

    func delete(
        checkpointRef: String,
        preparedPolicy: PolicySnapshot,
        executionContext: ToolExecutionContext?
    ) throws -> [String: Any] {
        try requireContinue(executionContext)
        try initialize()
        lock.lock()
        let record = records.first { $0.checkpointRef == checkpointRef }
        lock.unlock()
        guard let record else { throw MCPServerError.notFound("Unknown or expired checkpoint_ref") }
        let manifest = try loadManifest(record)
        try policy.authorize("checkpoint_delete", prepared: preparedPolicy)
        try requireContinue(executionContext)

        var refs = Set(manifest.entries.flatMap { entry -> [String] in
            [entry.indexContentRef, entry.worktreeContentRef].compactMap { $0 }
        })
        refs.insert(record.checkpointRef)
        for ref in refs {
            _ = try? artifactFactory().delete(
                ref,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClassAllowed: { $0 == ArtifactContentClasses.checkpoint }
            )
        }

        lock.lock()
        let candidate = records.filter { $0.checkpointRef != checkpointRef }
        do {
            try persistIndex(candidate)
            records = candidate
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
        return ["checkpoint_ref": checkpointRef, "deleted": true]
    }

    private func loadManifest(_ record: CheckpointRecord) throws -> CheckpointManifest {
        let output = OutputStream.toMemory()
        output.open()
        defer { output.close() }
        try artifactFactory().copy(
            record.checkpointRef,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: { $0 == ArtifactContentClasses.checkpoint },
            to: output
        )
        let descriptor = try artifactFactory().resolve(
            record.checkpointRef,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: { $0 == ArtifactContentClasses.checkpoint }
        )
        guard descriptor.blobID == record.manifestHash else {
            throw MCPServerError.operationFailed("Checkpoint manifest digest mismatch")
        }
        guard let data = output.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
            throw MCPServerError.operationFailed("Checkpoint manifest could not be read")
        }
        let manifest = try JSONDecoder().decode(CheckpointManifest.self, from: data)
        try Self.validateManifest(manifest)
        guard manifest.workspaceAuthorityID == workspaceAuthorityID else {
            throw MCPServerError.operationFailed("Checkpoint workspace identity mismatch")
        }
        return manifest
    }

    private func initialize() throws {
        lock.lock()
        defer { lock.unlock() }
        if initialized { return }
        try FileManager.default.createDirectory(at: metadataRoot, withIntermediateDirectories: true)
        chmod(metadataRoot.path, S_IRWXU)
        if FileManager.default.fileExists(atPath: indexURL.path) {
            let data = try Data(contentsOf: indexURL)
            records = try JSONDecoder().decode([CheckpointRecord].self, from: data)
            for record in records { try Self.validateRecord(record) }
        }
        initialized = true
    }

    private func addRecord(_ record: CheckpointRecord) throws {
        try Self.validateRecord(record)
        try initialize()
        lock.lock()
        defer { lock.unlock() }
        let nowMs = epochMs(options.now())
        var candidate = records.filter { $0.expiresEpochMs > nowMs }
        candidate.append(record)
        try persistIndex(candidate)
        records = candidate
    }

    private func pruneExpired() throws {
        try initialize()
        lock.lock()
        let nowMs = epochMs(options.now())
        let candidate = records.filter { $0.expiresEpochMs > nowMs }
        let changed = candidate.count != records.count
        do {
            if changed {
                try persistIndex(candidate)
                records = candidate
            }
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
        _ = try artifactFactory().collectGarbage()
    }

    private func persistIndex(_ candidate: [CheckpointRecord]) throws {
        try FileManager.default.createDirectory(at: metadataRoot, withIntermediateDirectories: true)
        chmod(metadataRoot.path, S_IRWXU)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(candidate)
        let temp = metadataRoot.appendingPathComponent("index-v1.json.tmp-\(UUID().uuidString)")
        try data.write(to: temp, options: [.atomic])
        chmod(temp.path, S_IRUSR | S_IWUSR)
        if FileManager.default.fileExists(atPath: indexURL.path) {
            _ = try FileManager.default.replaceItemAt(indexURL, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: indexURL)
        }
        chmod(indexURL.path, S_IRUSR | S_IWUSR)
    }

    private func recordMetadata(_ record: CheckpointRecord, manifest: CheckpointManifest? = nil) -> [String: Any] {
        var result: [String: Any] = [
            "checkpoint_ref": record.checkpointRef,
            "manifest_hash": record.manifestHash,
            "repository_relative_path": record.repositoryRelativePath,
            "head_oid": record.headOid.map { $0 as Any } ?? NSNull(),
            "source_state_id": record.sourceStateId,
            "created_epoch_ms": record.createdEpochMs,
            "expires_epoch_ms": record.expiresEpochMs,
            "expired": false,
            "entry_count": record.entryCount,
            "total_bytes": record.totalBytes,
            "staged_count": record.stagedCount,
            "unstaged_count": record.unstagedCount,
            "untracked_count": record.untrackedCount,
            "ignored_count": record.ignoredCount,
            "excluded_count": record.excludedCount,
            "workspace_authority_id": record.workspaceAuthorityID,
        ]
        if let manifest {
            result["entries"] = manifest.entries.map { entry in
                [
                    "relative_path": entry.relativePath,
                    "staged": entry.staged,
                    "unstaged": entry.unstaged,
                    "untracked": entry.untracked,
                    "ignored": entry.ignored,
                    "generated": entry.generated,
                    "worktree_exists": entry.worktreeExists,
                    "index_size_bytes": entry.indexSizeBytes,
                    "worktree_size_bytes": entry.worktreeSizeBytes,
                    "index_sha256": entry.indexSha256.map { $0 as Any } ?? NSNull(),
                    "worktree_sha256": entry.worktreeSha256.map { $0 as Any } ?? NSNull(),
                    "index_excluded_reason": entry.indexExcludedReason.map { $0 as Any } ?? NSNull(),
                    "worktree_excluded_reason": entry.worktreeExcludedReason.map { $0 as Any } ?? NSNull(),
                ] as [String: Any]
            }
            result["include_untracked"] = manifest.includeUntracked
            result["include_ignored"] = manifest.includeIgnored
            result["include_generated"] = manifest.includeGenerated
            result["index_fingerprint"] = manifest.indexFingerprint
        }
        return result
    }

    private func enforcePayloadBounds(
        _ path: String,
        _ bytes: Int64,
        totalBytes: inout Int64,
        maximum: Int64
    ) throws {
        guard bytes >= 0 else {
            throw MCPServerError.operationFailed("Checkpoint file size is invalid: \(path)")
        }
        guard totalBytes <= maximum - bytes else {
            throw MCPServerError.operationFailed("Checkpoint payload exceeds max_total_bytes (\(maximum))")
        }
        totalBytes += bytes
    }

    private func relativeToWorkspace(_ url: URL) -> String {
        let root = resolver.root.path
        let path = url.standardizedFileURL.path
        if path == root { return "" }
        if path.hasPrefix(root + "/") { return String(path.dropFirst(root.count + 1)) }
        return path
    }

    private func requireContinue(_ context: ToolExecutionContext?) throws {
        if let context, !context.tryContinue() {
            throw MCPServerError.operationFailed("Checkpoint operation aborted: \(context.truncationReason)")
        }
    }

    private func resolveTTL(_ seconds: Int) throws -> TimeInterval {
        let ttl = seconds == 0 ? options.defaultTTL : TimeInterval(seconds)
        guard ttl > 0, ttl <= options.maxTTL else {
            throw MCPServerError.invalidArguments("ttl_seconds must be between 1 and \(Int(options.maxTTL))")
        }
        return ttl
    }

    private static func validateOptions(_ options: WorkspaceCheckpointOptions) throws {
        guard options.defaultTTL > 0, options.defaultTTL <= options.maxTTL,
              options.maxEntries > 0, options.maxEntries <= 50_000,
              options.maxTotalBytes > 0, options.maxTotalBytes <= 512 * 1024 * 1024,
              options.maxSingleFileBytes > 0, options.maxSingleFileBytes <= options.maxTotalBytes else {
            throw MCPServerError.invalidArguments("Workspace checkpoint options are invalid")
        }
    }

    private static func isGeneratedPath(_ path: String) -> Bool {
        let generated: Set<String> = [
            "node_modules", ".venv", "venv", "__pycache__", "build", "dist", "out", "target", ".gradle",
        ]
        return path.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .contains { generated.contains(String($0).lowercased()) }
    }

    private static func validateRepoRelativePath(_ path: String) throws {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !normalized.hasPrefix("/"),
              !normalized.contains("\0"),
              normalized != ".",
              !normalized.hasPrefix("../"),
              !normalized.contains("/../") else {
            throw MCPServerError.invalidArguments("Checkpoint path is invalid")
        }
    }

    private func requiredString(_ object: [String: Any], _ key: String) throws -> String {
        guard let value = object[key] as? String, !value.isEmpty else {
            throw MCPServerError.operationFailed("Checkpoint SourceStateRef is missing \(key)")
        }
        return value
    }

    private func optionalString(_ object: [String: Any], _ key: String) -> String? {
        guard let value = object[key] as? String, !value.isEmpty else { return nil }
        return value
    }

    private func splitNul(_ value: String) -> [String] {
        Array(Set(value.split(separator: "\0", omittingEmptySubsequences: true).map {
            String($0).replacingOccurrences(of: "\\", with: "/")
        })).sorted()
    }

    private func epochMs(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    private static func validateRecord(_ record: CheckpointRecord) throws {
        guard !record.checkpointRef.isEmpty, !record.manifestHash.isEmpty,
              !record.workspaceAuthorityID.isEmpty, !record.sourceStateId.isEmpty,
              record.createdEpochMs > 0, record.expiresEpochMs > record.createdEpochMs,
              record.entryCount >= 0, record.totalBytes >= 0 else {
            throw MCPServerError.operationFailed("Checkpoint metadata index is invalid")
        }
    }

    private static func validateManifest(_ manifest: CheckpointManifest) throws {
        guard manifest.schemaVersion == schemaVersion,
              !manifest.workspaceAuthorityID.isEmpty,
              !manifest.sourceStateId.isEmpty,
              !manifest.indexFingerprint.isEmpty,
              manifest.createdEpochMs > 0,
              manifest.expiresEpochMs > manifest.createdEpochMs,
              manifest.totalBytes >= 0 else {
            throw MCPServerError.operationFailed("Checkpoint manifest is invalid")
        }
    }
}

private struct CheckpointRecord: Codable {
    let checkpointRef: String
    let manifestHash: String
    let workspaceAuthorityID: String
    let repositoryRelativePath: String
    let headOid: String?
    let sourceStateId: String
    let createdEpochMs: Int64
    let expiresEpochMs: Int64
    let entryCount: Int
    let totalBytes: Int64
    let stagedCount: Int
    let unstagedCount: Int
    let untrackedCount: Int
    let ignoredCount: Int
    let excludedCount: Int
}

private struct CheckpointManifest: Codable {
    let schemaVersion: Int
    let workspaceAuthorityID: String
    let repositoryRelativePath: String
    let headOid: String?
    let indexFingerprint: String
    let sourceStateId: String
    let createdEpochMs: Int64
    let expiresEpochMs: Int64
    let includeUntracked: Bool
    let includeIgnored: Bool
    let includeGenerated: Bool
    let stagedCount: Int
    let unstagedCount: Int
    let untrackedCount: Int
    let ignoredCount: Int
    let excludedCount: Int
    let totalBytes: Int64
    let entries: [CheckpointManifestEntry]
}

private struct CheckpointManifestEntry: Codable {
    let relativePath: String
    let staged: Bool
    let unstaged: Bool
    let untracked: Bool
    let ignored: Bool
    let generated: Bool
    let worktreeExists: Bool
    let indexContentRef: String?
    let indexSha256: String?
    let indexSizeBytes: Int64
    let indexExcludedReason: String?
    let worktreeContentRef: String?
    let worktreeSha256: String?
    let worktreeSizeBytes: Int64
    let worktreeExcludedReason: String?
}
