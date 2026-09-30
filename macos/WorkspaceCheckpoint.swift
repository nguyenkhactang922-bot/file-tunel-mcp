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
    var restoreStageForTests: ((String) throws -> Void)?
}

final class WorkspaceCheckpointService {
    private static let schemaVersion = 2
    private static let minimumSchemaVersion = 1
    private let resolver: SafePathResolver
    private let artifactFactory: () throws -> ArtifactContentStore
    private let policy: ServerPolicy
    private let mutationGuard: AuthorizedPathSnapshotService
    private let options: WorkspaceCheckpointOptions
    private let resolveRepo: (String) throws -> URL
    private let runGit: (URL, [String], Int, Bool) throws -> String
    private let readIndexBlob: (URL, String) throws -> Data?
    private let readGitObjectBlob: (URL, String) throws -> Data
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
        mutationGuard: AuthorizedPathSnapshotService,
        resolveRepo: @escaping (String) throws -> URL,
        runGit: @escaping (URL, [String], Int, Bool) throws -> String,
        readIndexBlob: @escaping (URL, String) throws -> Data?,
        readGitObjectBlob: @escaping (URL, String) throws -> Data,
        captureSourceState: @escaping (String, [String]) throws -> [String: Any],
        options: WorkspaceCheckpointOptions = WorkspaceCheckpointOptions()
    ) throws {
        try Self.validateOptions(options)
        self.resolver = resolver
        self.artifactFactory = artifactFactory
        self.policy = policy
        self.mutationGuard = mutationGuard
        self.options = options
        self.resolveRepo = resolveRepo
        self.runGit = runGit
        self.readIndexBlob = readIndexBlob
        self.readGitObjectBlob = readGitObjectBlob
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
                var indexMode: String?
                var indexExcludedReason: String?
                if stagedSet.contains(path) {
                    indexMode = try readIndexMode(repo: repo, path: path)
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
                    indexMode: indexMode,
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
                _ = try? artifactFactory().delete(
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
                    "index_mode": entry.indexMode.map { $0 as Any } ?? NSNull(),
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

    private func readIndexMode(repo: URL, path: String) throws -> String? {
        let listed = try runGit(repo, ["ls-files", "-s", "--", path], 8 * 1024 * 1024, true)
        for line in listed.split(whereSeparator: { $0.isNewline }) {
            guard let tab = line.firstIndex(of: "\t") else { continue }
            let metadata = line[..<tab].split(separator: " ")
            guard metadata.count >= 3, metadata[2] == "0" else { continue }
            let mode = String(metadata[0])
            guard ["100644", "100755", "120000"].contains(mode) else {
                throw MCPServerError.operationFailed("Checkpoint does not support Git index mode \(mode) for \(path)")
            }
            return mode
        }
        return nil
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
        guard manifest.schemaVersion >= minimumSchemaVersion,
              manifest.schemaVersion <= schemaVersion,
              !manifest.workspaceAuthorityID.isEmpty,
              !manifest.sourceStateId.isEmpty,
              !manifest.indexFingerprint.isEmpty,
              manifest.createdEpochMs > 0,
              manifest.expiresEpochMs > manifest.createdEpochMs,
              manifest.totalBytes >= 0 else {
            throw MCPServerError.operationFailed("Checkpoint manifest is invalid")
        }
    }


    private var restoreJournalURL: URL {
        metadataRoot.appendingPathComponent("restore-active-v1.json", isDirectory: false)
    }

    func restore(
        checkpointRef: String,
        historyMode rawHistoryMode: String,
        dryRun: Bool,
        preparedPolicy: PolicySnapshot,
        executionContext: ToolExecutionContext?
    ) throws -> [String: Any] {
        try requireContinue(executionContext)
        guard !checkpointRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MCPServerError.invalidArguments("checkpoint_ref must be non-empty")
        }
        let historyMode = rawHistoryMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "preserve"
            : rawHistoryMode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard historyMode == "preserve" || historyMode == "move" else {
            throw MCPServerError.invalidArguments("history_mode must be preserve or move")
        }

        if let recovered = try recoverIncompleteRestore(
            preparedPolicy: preparedPolicy,
            executionContext: executionContext
        ) {
            return recovered
        }

        let (record, manifest) = try checkpointForRestore(checkpointRef)
        let repo = try resolveRepo(manifest.repositoryRelativePath)
        let currentHead = try readHeadOID(repo)
        let targetHead = manifest.headOid

        if currentHead != targetHead {
            guard historyMode == "move" else {
                throw MCPServerError.operationFailed(
                    "Checkpoint restore refused because repository HEAD diverged from checkpoint base"
                )
            }
            guard policy.allowsExplicitHistoryMove else {
                throw MCPServerError.operationFailed(
                    "history_mode=move requires explicit custom high-risk local policy with write and delete effects"
                )
            }
            guard let currentHead, let targetHead else {
                throw MCPServerError.operationFailed("History-moving restore does not support unborn HEAD state")
            }
            _ = try requireCommit(repo, oid: targetHead)
            _ = currentHead
        }

        let plan = try buildRestorePlan(repo: repo, manifest: manifest)
        if dryRun {
            return restoreResult(
                checkpointRef: checkpointRef,
                state: "planned",
                repoRelative: manifest.repositoryRelativePath,
                historyMode: historyMode,
                originalHead: currentHead,
                targetHead: targetHead,
                rollbackRef: nil,
                plan: plan,
                recoveredIncomplete: false
            )
        }

        try policy.authorize("checkpoint_restore", prepared: preparedPolicy)
        try requireContinue(executionContext)

        let planPaths = plan.paths.map(\.relativePath)
        let planStateBefore = try captureSourceState(manifest.repositoryRelativePath, planPaths)
        let planStateID = try requiredString(planStateBefore, "source_state_id")

        let rollbackMetadata = try capture(
            repoPath: manifest.repositoryRelativePath,
            includeUntracked: manifest.includeUntracked,
            includeIgnored: manifest.includeIgnored,
            includeGenerated: manifest.includeGenerated,
            ttlSeconds: Int(options.maxTTL),
            maxFiles: options.maxEntries,
            maxTotalBytes: options.maxTotalBytes,
            preparedPolicy: preparedPolicy,
            executionContext: executionContext
        )
        let rollbackRef = try requiredString(rollbackMetadata, "checkpoint_ref")
        let (rollbackRecord, rollbackManifest) = try checkpointForRestore(rollbackRef)

        do {
            try ensureRollbackCoverage(targetPlan: plan, rollbackManifest: rollbackManifest)
            try options.restoreStageForTests?("after_restore_plan")
            try requireContinue(executionContext)

            let planStateAfter = try captureSourceState(manifest.repositoryRelativePath, planPaths)
            guard planStateID == (try requiredString(planStateAfter, "source_state_id")) else {
                try deleteCheckpointInternal(record: rollbackRecord, manifest: rollbackManifest)
                throw MCPServerError.operationFailed(
                    "Repository changed after checkpoint restore plan validation"
                )
            }

            var journal = CheckpointRestoreJournal(
                transactionId: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
                phase: "prepared",
                targetCheckpointRef: checkpointRef,
                rollbackCheckpointRef: rollbackRef,
                repositoryRelativePath: manifest.repositoryRelativePath,
                originalHeadOid: currentHead,
                targetHeadOid: targetHead,
                historyMode: historyMode,
                startedEpochMs: epochMs(options.now())
            )
            try persistRestoreJournal(journal)

            var mutationStarted = false
            do {
                if currentHead != targetHead {
                    guard let currentHead, let targetHead else {
                        throw MCPServerError.operationFailed("History-moving restore lost HEAD identity")
                    }
                    mutationStarted = true
                    try moveHead(repo, from: currentHead, to: targetHead)
                }

                try applyRestorePlan(
                    repo: repo,
                    manifest: manifest,
                    plan: plan,
                    preparedPolicy: preparedPolicy,
                    executionContext: executionContext,
                    isRollback: false,
                    mutationStarted: { mutationStarted = true }
                )

                try options.restoreStageForTests?("before_restore_verify")
                try verifyRestorePlan(repo: repo, manifest: manifest, plan: plan)
                journal.phase = "verified"
                try persistRestoreJournal(journal)

                var cleanupPending = false
                do {
                    try deleteCheckpointInternal(record: rollbackRecord, manifest: rollbackManifest)
                    try deleteRestoreJournal()
                } catch {
                    cleanupPending = true
                }

                var result = restoreResult(
                    checkpointRef: checkpointRef,
                    state: "restored",
                    repoRelative: manifest.repositoryRelativePath,
                    historyMode: historyMode,
                    originalHead: currentHead,
                    targetHead: targetHead,
                    rollbackRef: cleanupPending ? rollbackRef : nil,
                    plan: plan,
                    recoveredIncomplete: false
                )
                result["cleanup_pending"] = cleanupPending
                _ = record
                return result
            } catch let crash as WorkspaceCheckpointCrashForTestsError {
                throw crash
            } catch {
                let restoreError = error
                if !mutationStarted {
                    try? deleteCheckpointInternal(record: rollbackRecord, manifest: rollbackManifest)
                    deleteRestoreJournalBestEffort()
                    throw restoreError
                }

                do {
                    try options.restoreStageForTests?("before_restore_rollback")
                    try rollbackFromJournal(
                        journal,
                        rollbackRecord: rollbackRecord,
                        rollbackManifest: rollbackManifest,
                        preparedPolicy: preparedPolicy,
                        executionContext: executionContext
                    )
                    journal.phase = "rolled_back"
                    try persistRestoreJournal(journal)
                    do {
                        try deleteCheckpointInternal(record: rollbackRecord, manifest: rollbackManifest)
                        try deleteRestoreJournal()
                    } catch { }

                    return restoreResult(
                        checkpointRef: checkpointRef,
                        state: "rolled_back",
                        repoRelative: manifest.repositoryRelativePath,
                        historyMode: historyMode,
                        originalHead: currentHead,
                        targetHead: targetHead,
                        rollbackRef: FileManager.default.fileExists(atPath: restoreJournalURL.path) ? rollbackRef : nil,
                        plan: plan,
                        recoveredIncomplete: false,
                        error: restoreError.localizedDescription
                    )
                } catch {
                    let rollbackError = error
                    journal.phase = "partial_recovery_required"
                    persistRestoreJournalBestEffort(journal)
                    return restoreResult(
                        checkpointRef: checkpointRef,
                        state: "partial_recovery_required",
                        repoRelative: manifest.repositoryRelativePath,
                        historyMode: historyMode,
                        originalHead: currentHead,
                        targetHead: targetHead,
                        rollbackRef: rollbackRef,
                        plan: plan,
                        recoveredIncomplete: false,
                        error: restoreError.localizedDescription,
                        rollbackError: rollbackError.localizedDescription
                    )
                }
            }
        } catch {
            if !FileManager.default.fileExists(atPath: restoreJournalURL.path) {
                try? deleteCheckpointInternal(record: rollbackRecord, manifest: rollbackManifest)
            }
            throw error
        }
    }

    private func recoverIncompleteRestore(
        preparedPolicy: PolicySnapshot,
        executionContext: ToolExecutionContext?
    ) throws -> [String: Any]? {
        guard var journal = try loadRestoreJournal() else { return nil }
        let (rollbackRecord, rollbackManifest) = try checkpointForRestore(journal.rollbackCheckpointRef)

        if journal.phase == "verified" {
            do {
                try deleteCheckpointInternal(record: rollbackRecord, manifest: rollbackManifest)
                try deleteRestoreJournal()
            } catch { }
            var result = restoreResult(
                checkpointRef: journal.targetCheckpointRef,
                state: "restored",
                repoRelative: journal.repositoryRelativePath,
                historyMode: journal.historyMode,
                originalHead: journal.originalHeadOid,
                targetHead: journal.targetHeadOid,
                rollbackRef: FileManager.default.fileExists(atPath: restoreJournalURL.path)
                    ? journal.rollbackCheckpointRef : nil,
                plan: CheckpointRestorePlan(),
                recoveredIncomplete: true
            )
            result["cleanup_pending"] = FileManager.default.fileExists(atPath: restoreJournalURL.path)
            return result
        }

        if journal.phase == "rolled_back" {
            do {
                try deleteCheckpointInternal(record: rollbackRecord, manifest: rollbackManifest)
                try deleteRestoreJournal()
            } catch { }
            return restoreResult(
                checkpointRef: journal.targetCheckpointRef,
                state: "rolled_back",
                repoRelative: journal.repositoryRelativePath,
                historyMode: journal.historyMode,
                originalHead: journal.originalHeadOid,
                targetHead: journal.targetHeadOid,
                rollbackRef: FileManager.default.fileExists(atPath: restoreJournalURL.path)
                    ? journal.rollbackCheckpointRef : nil,
                plan: CheckpointRestorePlan(),
                recoveredIncomplete: true
            )
        }

        if journal.phase == "partial_recovery_required" {
            return restoreResult(
                checkpointRef: journal.targetCheckpointRef,
                state: "partial_recovery_required",
                repoRelative: journal.repositoryRelativePath,
                historyMode: journal.historyMode,
                originalHead: journal.originalHeadOid,
                targetHead: journal.targetHeadOid,
                rollbackRef: journal.rollbackCheckpointRef,
                plan: CheckpointRestorePlan(),
                recoveredIncomplete: true,
                error: "Previous checkpoint restore requires recovery"
            )
        }

        do {
            try rollbackFromJournal(
                journal,
                rollbackRecord: rollbackRecord,
                rollbackManifest: rollbackManifest,
                preparedPolicy: preparedPolicy,
                executionContext: executionContext
            )
            journal.phase = "rolled_back"
            try persistRestoreJournal(journal)
            do {
                try deleteCheckpointInternal(record: rollbackRecord, manifest: rollbackManifest)
                try deleteRestoreJournal()
            } catch { }
            return restoreResult(
                checkpointRef: journal.targetCheckpointRef,
                state: "rolled_back",
                repoRelative: journal.repositoryRelativePath,
                historyMode: journal.historyMode,
                originalHead: journal.originalHeadOid,
                targetHead: journal.targetHeadOid,
                rollbackRef: FileManager.default.fileExists(atPath: restoreJournalURL.path)
                    ? journal.rollbackCheckpointRef : nil,
                plan: CheckpointRestorePlan(),
                recoveredIncomplete: true,
                error: "Recovered interrupted checkpoint restore"
            )
        } catch {
            let rollbackError = error
            journal.phase = "partial_recovery_required"
            persistRestoreJournalBestEffort(journal)
            return restoreResult(
                checkpointRef: journal.targetCheckpointRef,
                state: "partial_recovery_required",
                repoRelative: journal.repositoryRelativePath,
                historyMode: journal.historyMode,
                originalHead: journal.originalHeadOid,
                targetHead: journal.targetHeadOid,
                rollbackRef: journal.rollbackCheckpointRef,
                plan: CheckpointRestorePlan(),
                recoveredIncomplete: true,
                error: "Interrupted checkpoint restore rollback failed",
                rollbackError: rollbackError.localizedDescription
            )
        }
    }

    private func rollbackFromJournal(
        _ journal: CheckpointRestoreJournal,
        rollbackRecord: CheckpointRecord,
        rollbackManifest: CheckpointManifest,
        preparedPolicy: PolicySnapshot,
        executionContext: ToolExecutionContext?
    ) throws {
        let repo = try resolveRepo(journal.repositoryRelativePath)
        let currentHead = try readHeadOID(repo)
        if currentHead != journal.originalHeadOid {
            guard journal.historyMode == "move",
                  let originalHead = journal.originalHeadOid,
                  let currentHead else {
                throw MCPServerError.operationFailed(
                    "Rollback refused because repository HEAD no longer matches restore transaction"
                )
            }
            try moveHead(repo, from: currentHead, to: originalHead)
        }

        let rollbackPlan = try buildRestorePlan(repo: repo, manifest: rollbackManifest)
        try options.restoreStageForTests?("during_restore_rollback")
        try applyRestorePlan(
            repo: repo,
            manifest: rollbackManifest,
            plan: rollbackPlan,
            preparedPolicy: preparedPolicy,
            executionContext: executionContext,
            isRollback: true,
            mutationStarted: {}
        )
        try verifyRestorePlan(repo: repo, manifest: rollbackManifest, plan: rollbackPlan)
        _ = rollbackRecord
    }

    private func buildRestorePlan(
        repo: URL,
        manifest: CheckpointManifest
    ) throws -> CheckpointRestorePlan {
        let currentStaged = splitNul(try runGit(
            repo, ["diff", "--cached", "--name-only", "--diff-filter=ACMRD", "-z", "--"],
            8 * 1024 * 1024, false))
        let currentUnstaged = splitNul(try runGit(
            repo, ["diff", "--name-only", "--diff-filter=ACMRD", "-z", "--"],
            8 * 1024 * 1024, false))
        let currentUntracked = manifest.includeUntracked
            ? splitNul(try runGit(
                repo, ["ls-files", "--others", "--exclude-standard", "-z", "--"],
                8 * 1024 * 1024, false))
            : []
        let currentIgnored = manifest.includeIgnored
            ? splitNul(try runGit(
                repo, ["ls-files", "--others", "--ignored", "--exclude-standard", "-z", "--"],
                8 * 1024 * 1024, false))
            : []
        let currentHead = try readHeadOID(repo)
        let historyChanged: [String]
        if let currentHead, let targetHead = manifest.headOid, currentHead.lowercased() != targetHead.lowercased() {
            historyChanged = splitNul(try runGit(
                repo, ["diff", "--name-only", "-z", currentHead, targetHead, "--"],
                8 * 1024 * 1024, false))
        } else {
            historyChanged = []
        }

        func managed(_ paths: [String]) -> [String] {
            manifest.includeGenerated ? paths : paths.filter { !Self.isGeneratedPath($0) }
        }

        var targetEntries: [String: CheckpointManifestEntry] = [:]
        for entry in manifest.entries {
            guard targetEntries[entry.relativePath] == nil else {
                throw MCPServerError.operationFailed("Checkpoint manifest contains duplicate paths")
            }
            targetEntries[entry.relativePath] = entry
        }

        let allPaths = Array(Set(
            Array(targetEntries.keys)
                + managed(currentStaged)
                + managed(currentUnstaged)
                + managed(currentUntracked)
                + managed(currentIgnored)
                + managed(historyChanged)
        )).sorted()
        guard allPaths.count <= options.maxEntries else {
            throw MCPServerError.operationFailed("Checkpoint restore plan exceeds maximum entry count")
        }

        let plan = CheckpointRestorePlan()
        for path in allPaths {
            try Self.validateRepoRelativePath(path)
            let target = targetEntries[path]
            let baseEntry = try readTreeEntry(repo: repo, headOid: manifest.headOid, path: path)
            let item = CheckpointRestorePathPlan(relativePath: path)

            if let target, target.generated && !manifest.includeGenerated {
                item.skipIndex = target.staged
                item.skipWorktree = true
                item.skipReason = "generated"
            } else {
                try resolveDesiredIndex(item: item, target: target, baseEntry: baseEntry)
                try resolveDesiredWorktree(
                    item: item,
                    target: target,
                    baseEntry: baseEntry,
                    repo: repo,
                    headOid: manifest.headOid
                )
            }

            let full = repo.appendingPathComponent(path).standardizedFileURL
            try ensurePathInsideRepo(repo: repo, full: full)
            let exists = try requireRegularOrMissing(full, relativePath: path)

            if !item.skipWorktree {
                item.currentWorktreeExists = exists
                item.needsWorktreeMutation = item.desiredWorktreeExists != exists
                if item.desiredWorktreeExists, exists, let expectedHash = item.desiredWorktreeSHA256 {
                    let hashed = try FileVersionService.sha256File(full, maxBytes: 64 * 1024 * 1024)
                    item.needsWorktreeMutation = hashed.hash != expectedHash
                }

                if item.needsWorktreeMutation {
                    let sharedRelative = relativeToWorkspace(full)
                    item.worktreeGuard = try exists
                        ? mutationGuard.captureExisting(relativePath: sharedRelative)
                        : mutationGuard.captureNewTarget(relativePath: sharedRelative)
                }
            }

            if item.skipIndex { plan.hasIndexSkips = true }
            if item.skipWorktree { plan.hasWorktreeSkips = true }
            if item.skipIndex || item.skipWorktree { plan.skippedCount += 1 }
            plan.paths.append(item)
        }
        return plan
    }

    private func resolveDesiredIndex(
        item: CheckpointRestorePathPlan,
        target: CheckpointManifestEntry?,
        baseEntry: CheckpointGitTreeEntry?
    ) throws {
        if let target, target.staged {
            if let excluded = target.indexExcludedReason, !excluded.isEmpty {
                item.skipIndex = true
                item.skipReason = excluded
                return
            }
            guard let contentRef = target.indexContentRef else {
                item.desiredIndexExists = false
                return
            }
            guard let mode = target.indexMode, !mode.isEmpty else {
                throw MCPServerError.operationFailed(
                    "Checkpoint staged restore requires schema-v2 index_mode for \(target.relativePath)"
                )
            }
            try validateIndexMode(mode)
            item.desiredIndexBytes = try readCheckpointPayload(
                contentRef: contentRef,
                expectedHash: target.indexSha256,
                expectedSize: target.indexSizeBytes
            )
            item.desiredIndexExists = true
            item.desiredIndexMode = mode
            return
        }

        guard let baseEntry else {
            item.desiredIndexExists = false
            return
        }
        try validateIndexMode(baseEntry.mode)
        item.desiredIndexExists = true
        item.desiredIndexMode = baseEntry.mode
        item.desiredIndexOID = baseEntry.oid
    }

    private func resolveDesiredWorktree(
        item: CheckpointRestorePathPlan,
        target: CheckpointManifestEntry?,
        baseEntry: CheckpointGitTreeEntry?,
        repo: URL,
        headOid: String?
    ) throws {
        if let target {
            if let excluded = target.worktreeExcludedReason, !excluded.isEmpty {
                item.skipWorktree = true
                if item.skipReason == nil { item.skipReason = excluded }
                return
            }
            guard target.worktreeExists else {
                item.desiredWorktreeExists = false
                return
            }
            guard let contentRef = target.worktreeContentRef,
                  let expectedHash = target.worktreeSha256,
                  !expectedHash.isEmpty else {
                throw MCPServerError.operationFailed(
                    "Checkpoint worktree payload is missing for \(target.relativePath)"
                )
            }
            item.desiredWorktreeBytes = try readCheckpointPayload(
                contentRef: contentRef,
                expectedHash: expectedHash,
                expectedSize: target.worktreeSizeBytes
            )
            item.desiredWorktreeExists = true
            item.desiredWorktreeSHA256 = expectedHash
            item.desiredWorktreeMode = target.indexMode ?? baseEntry?.mode
            return
        }

        guard let baseEntry else {
            item.desiredWorktreeExists = false
            return
        }
        guard baseEntry.type == "blob",
              baseEntry.mode == "100644" || baseEntry.mode == "100755" else {
            throw MCPServerError.operationFailed(
                "Checkpoint restore cannot materialize Git tree mode \(baseEntry.mode) for \(item.relativePath)"
            )
        }
        guard headOid != nil else {
            throw MCPServerError.operationFailed("Checkpoint base HEAD is unavailable for worktree restore")
        }
        let data = try readGitObjectBlob(repo, baseEntry.oid)
        item.desiredWorktreeExists = true
        item.desiredWorktreeBytes = data
        item.desiredWorktreeSHA256 = FileVersionService.sha256Tagged(data)
        item.desiredWorktreeMode = baseEntry.mode
    }

    private func applyRestorePlan(
        repo: URL,
        manifest: CheckpointManifest,
        plan: CheckpointRestorePlan,
        preparedPolicy: PolicySnapshot,
        executionContext: ToolExecutionContext?,
        isRollback: Bool,
        mutationStarted: () -> Void
    ) throws {
        for item in plan.paths where !item.skipWorktree && item.needsWorktreeMutation {
            try requireContinue(executionContext)
            try policy.authorize("checkpoint_restore", prepared: preparedPolicy)
            guard let guardSnapshot = item.worktreeGuard else {
                throw MCPServerError.operationFailed("Checkpoint restore Mutation Guard is missing")
            }
            _ = try mutationGuard.verify(guardSnapshot)
            mutationStarted()

            let full = repo.appendingPathComponent(item.relativePath).standardizedFileURL
            try ensurePathInsideRepo(repo: repo, full: full)
            if !item.desiredWorktreeExists {
                if FileManager.default.fileExists(atPath: full.path) {
                    try FileManager.default.removeItem(at: full)
                }
            } else {
                let parent = full.deletingLastPathComponent()
                var parentIsDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &parentIsDirectory),
                      parentIsDirectory.boolValue else {
                    throw MCPServerError.operationFailed(
                        "Checkpoint restore target parent must already exist: \(item.relativePath)"
                    )
                }
                let temp = parent.appendingPathComponent(
                    ".\(full.lastPathComponent).filemcp-checkpoint-restore-\(UUID().uuidString).tmp"
                )
                defer { try? FileManager.default.removeItem(at: temp) }
                guard let data = item.desiredWorktreeBytes else {
                    throw MCPServerError.operationFailed("Checkpoint restore worktree bytes are missing")
                }
                try data.write(to: temp, options: [])
                chmod(temp.path, S_IRUSR | S_IWUSR)
                let handle = try FileHandle(forWritingTo: temp)
                try handle.synchronize()
                try handle.close()
                _ = try mutationGuard.verify(guardSnapshot)
                if item.currentWorktreeExists {
                    _ = try FileManager.default.replaceItemAt(full, withItemAt: temp)
                } else {
                    try FileManager.default.moveItem(at: temp, to: full)
                }
                if item.desiredWorktreeMode == "100755" {
                    chmod(full.path, S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH)
                } else if item.desiredWorktreeMode == "100644" {
                    chmod(full.path, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
                }
            }
            try options.restoreStageForTests?(
                (isRollback ? "after_rollback_publish:" : "after_restore_publish:") + item.relativePath
            )
        }

        for item in plan.paths where !item.skipIndex {
            try requireContinue(executionContext)
            try policy.authorize("checkpoint_restore", prepared: preparedPolicy)
            mutationStarted()
            if !item.desiredIndexExists {
                _ = try runGit(
                    repo,
                    ["update-index", "--force-remove", "--", item.relativePath],
                    8 * 1024 * 1024,
                    true
                )
                continue
            }

            var oid = item.desiredIndexOID
            if oid == nil {
                guard let bytes = item.desiredIndexBytes else {
                    throw MCPServerError.operationFailed("Checkpoint restore staged bytes are missing")
                }
                oid = try writeGitBlob(repo: repo, data: bytes)
                item.desiredIndexOID = oid
            }
            guard let mode = item.desiredIndexMode, let oid else {
                throw MCPServerError.operationFailed("Checkpoint restore index identity is incomplete")
            }
            _ = try runGit(
                repo,
                ["update-index", "--add", "--cacheinfo", "\(mode),\(oid),\(item.relativePath)"],
                8 * 1024 * 1024,
                true
            )
        }
        _ = manifest
    }

    private func verifyRestorePlan(
        repo: URL,
        manifest: CheckpointManifest,
        plan: CheckpointRestorePlan
    ) throws {
        let head = try readHeadOID(repo)
        guard head == manifest.headOid else {
            throw MCPServerError.operationFailed("Checkpoint restore verification detected unexpected HEAD")
        }

        for item in plan.paths {
            if !item.skipIndex {
                let current = try readIndexEntry(repo: repo, path: item.relativePath)
                if !item.desiredIndexExists {
                    guard current == nil else {
                        throw MCPServerError.operationFailed(
                            "Checkpoint restore index verification failed: \(item.relativePath)"
                        )
                    }
                } else {
                    guard let current,
                          current.mode == item.desiredIndexMode,
                          current.oid.lowercased() == item.desiredIndexOID?.lowercased() else {
                        throw MCPServerError.operationFailed(
                            "Checkpoint restore index verification failed: \(item.relativePath)"
                        )
                    }
                }
            }

            if !item.skipWorktree {
                let full = repo.appendingPathComponent(item.relativePath).standardizedFileURL
                try ensurePathInsideRepo(repo: repo, full: full)
                let exists = FileManager.default.fileExists(atPath: full.path)
                if !item.desiredWorktreeExists {
                    guard !exists else {
                        throw MCPServerError.operationFailed(
                            "Checkpoint restore worktree verification failed: \(item.relativePath)"
                        )
                    }
                } else {
                    guard exists, let expected = item.desiredWorktreeSHA256 else {
                        throw MCPServerError.operationFailed(
                            "Checkpoint restore worktree verification failed: \(item.relativePath)"
                        )
                    }
                    let hashed = try FileVersionService.sha256File(full, maxBytes: 64 * 1024 * 1024)
                    guard hashed.hash == expected else {
                        throw MCPServerError.operationFailed(
                            "Checkpoint restore worktree digest verification failed: \(item.relativePath)"
                        )
                    }
                }
            }
        }

        if !plan.hasIndexSkips {
            let rawIndex = try runGit(repo, ["ls-files", "-s", "-z"], 8 * 1024 * 1024, false)
            guard FileVersionService.sha256Tagged(rawIndex) == manifest.indexFingerprint else {
                throw MCPServerError.operationFailed("Checkpoint restore final index fingerprint mismatch")
            }
        }
    }

    private func ensureRollbackCoverage(
        targetPlan: CheckpointRestorePlan,
        rollbackManifest: CheckpointManifest
    ) throws {
        var entries: [String: CheckpointManifestEntry] = [:]
        for entry in rollbackManifest.entries { entries[entry.relativePath] = entry }
        for item in targetPlan.paths where item.needsWorktreeMutation {
            if !item.currentWorktreeExists { continue }
            guard let rollbackEntry = entries[item.relativePath] else {
                continue // Clean tracked content is recoverable from rollback HEAD.
            }
            if let excluded = rollbackEntry.worktreeExcludedReason, !excluded.isEmpty {
                throw MCPServerError.operationFailed(
                    "Rollback checkpoint cannot cover \(item.relativePath): \(excluded)"
                )
            }
        }
        for entry in rollbackManifest.entries where entry.staged {
            if let excluded = entry.indexExcludedReason, !excluded.isEmpty {
                throw MCPServerError.operationFailed(
                    "Rollback checkpoint cannot cover staged index state for \(entry.relativePath): \(excluded)"
                )
            }
        }
    }

    private func checkpointForRestore(_ checkpointRef: String) throws -> (CheckpointRecord, CheckpointManifest) {
        try initialize()
        try pruneExpired()
        lock.lock()
        let record = records.first { $0.checkpointRef == checkpointRef }
        lock.unlock()
        guard let record else {
            throw MCPServerError.notFound("Unknown or expired checkpoint_ref")
        }
        return (record, try loadManifest(record))
    }

    private func readCheckpointPayload(
        contentRef: String,
        expectedHash: String?,
        expectedSize: Int64
    ) throws -> Data {
        let descriptor = try artifactFactory().resolve(
            contentRef,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: { $0 == ArtifactContentClasses.checkpoint }
        )
        if let expectedHash, !expectedHash.isEmpty, descriptor.blobID != expectedHash {
            throw MCPServerError.operationFailed("Checkpoint payload digest mismatch")
        }
        guard expectedSize < 0 || descriptor.sizeBytes == expectedSize else {
            throw MCPServerError.operationFailed("Checkpoint payload size mismatch")
        }
        guard descriptor.sizeBytes <= options.maxSingleFileBytes else {
            throw MCPServerError.operationFailed("Checkpoint payload exceeds restore single-file limit")
        }
        let output = OutputStream.toMemory()
        output.open()
        defer { output.close() }
        try artifactFactory().copy(
            contentRef,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: { $0 == ArtifactContentClasses.checkpoint },
            to: output
        )
        guard let data = output.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
            throw MCPServerError.operationFailed("Checkpoint payload could not be read")
        }
        if let expectedHash, !expectedHash.isEmpty,
           FileVersionService.sha256Tagged(data) != expectedHash {
            throw MCPServerError.operationFailed("Checkpoint payload digest verification failed")
        }
        return data
    }

    private func readTreeEntry(
        repo: URL,
        headOid: String?,
        path: String
    ) throws -> CheckpointGitTreeEntry? {
        guard let headOid, !headOid.isEmpty else { return nil }
        let raw = try runGit(repo, ["ls-tree", "-z", headOid, "--", path], 8 * 1024 * 1024, false)
        guard !raw.isEmpty else { return nil }
        guard let line = raw.split(separator: "\0", omittingEmptySubsequences: true).first,
              let tab = line.firstIndex(of: "\t") else {
            throw MCPServerError.operationFailed("Checkpoint restore could not parse Git tree entry")
        }
        let metadata = line[..<tab].split(separator: " ")
        guard metadata.count == 3 else {
            throw MCPServerError.operationFailed("Checkpoint restore Git tree entry is invalid")
        }
        return CheckpointGitTreeEntry(
            mode: String(metadata[0]),
            type: String(metadata[1]),
            oid: String(metadata[2])
        )
    }

    private func readIndexEntry(repo: URL, path: String) throws -> CheckpointGitTreeEntry? {
        let listed = try runGit(repo, ["ls-files", "-s", "--", path], 8 * 1024 * 1024, true)
        for line in listed.split(whereSeparator: { $0.isNewline }) {
            guard let tab = line.firstIndex(of: "\t") else { continue }
            let metadata = line[..<tab].split(separator: " ")
            guard metadata.count >= 3, metadata[2] == "0" else { continue }
            return CheckpointGitTreeEntry(
                mode: String(metadata[0]),
                type: "blob",
                oid: String(metadata[1])
            )
        }
        return nil
    }

    private func writeGitBlob(repo: URL, data: Data) throws -> String {
        try FileManager.default.createDirectory(at: metadataRoot, withIntermediateDirectories: true)
        chmod(metadataRoot.path, S_IRWXU)
        let temp = metadataRoot.appendingPathComponent("git-blob-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temp) }
        try data.write(to: temp, options: [])
        chmod(temp.path, S_IRUSR | S_IWUSR)
        let oid = try runGit(repo, ["hash-object", "-w", "--", temp.path], 8 * 1024 * 1024, true)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard oid.count >= 7, oid.count <= 128, oid.allSatisfy({ $0.isHexDigit }) else {
            throw MCPServerError.operationFailed("Checkpoint restore could not validate Git blob identity")
        }
        return oid
    }

    private func readHeadOID(_ repo: URL) throws -> String? {
        do {
            let value = try runGit(repo, ["rev-parse", "--verify", "HEAD"], 8 * 1024 * 1024, true)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.count >= 7, value.count <= 128, value.allSatisfy({ $0.isHexDigit }) else {
                throw MCPServerError.operationFailed("Checkpoint restore could not validate Git HEAD")
            }
            return value
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("needed a single revision")
                || message.contains("unknown revision")
                || message.contains("ambiguous argument") {
                return nil
            }
            throw error
        }
    }

    private func requireCommit(_ repo: URL, oid: String) throws -> String {
        let value = try runGit(repo, ["rev-parse", "--verify", oid + "^{commit}"], 8 * 1024 * 1024, true)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.lowercased() == oid.lowercased() else {
            throw MCPServerError.operationFailed(
                "Checkpoint restore target HEAD is not the expected commit"
            )
        }
        return value
    }

    private func moveHead(_ repo: URL, from: String, to: String) throws {
        _ = try requireCommit(repo, oid: to)
        _ = try runGit(repo, ["update-ref", "HEAD", to, from], 8 * 1024 * 1024, true)
        guard try readHeadOID(repo)?.lowercased() == to.lowercased() else {
            throw MCPServerError.operationFailed("Checkpoint restore history move verification failed")
        }
    }

    private func deleteCheckpointInternal(
        record: CheckpointRecord,
        manifest: CheckpointManifest
    ) throws {
        var refs = Set(manifest.entries.flatMap { entry -> [String] in
            [entry.indexContentRef, entry.worktreeContentRef].compactMap { $0 }
        })
        refs.insert(record.checkpointRef)
        for ref in refs {
            _ = try artifactFactory().delete(
                ref,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClassAllowed: { $0 == ArtifactContentClasses.checkpoint }
            )
        }

        lock.lock()
        let candidate = records.filter { $0.checkpointRef != record.checkpointRef }
        do {
            try persistIndex(candidate)
            records = candidate
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }
    }

    private func persistRestoreJournal(_ journal: CheckpointRestoreJournal) throws {
        try FileManager.default.createDirectory(at: metadataRoot, withIntermediateDirectories: true)
        chmod(metadataRoot.path, S_IRWXU)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(journal)
        let temp = metadataRoot.appendingPathComponent("restore-active-v1.json.tmp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }
        try data.write(to: temp, options: [])
        chmod(temp.path, S_IRUSR | S_IWUSR)
        if FileManager.default.fileExists(atPath: restoreJournalURL.path) {
            _ = try FileManager.default.replaceItemAt(restoreJournalURL, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: restoreJournalURL)
        }
        chmod(restoreJournalURL.path, S_IRUSR | S_IWUSR)
    }

    private func persistRestoreJournalBestEffort(_ journal: CheckpointRestoreJournal) {
        try? persistRestoreJournal(journal)
    }

    private func loadRestoreJournal() throws -> CheckpointRestoreJournal? {
        guard FileManager.default.fileExists(atPath: restoreJournalURL.path) else { return nil }
        do {
            return try JSONDecoder().decode(
                CheckpointRestoreJournal.self,
                from: Data(contentsOf: restoreJournalURL)
            )
        } catch {
            throw MCPServerError.operationFailed(
                "Checkpoint restore journal is corrupt: \(error.localizedDescription)"
            )
        }
    }

    private func deleteRestoreJournal() throws {
        if FileManager.default.fileExists(atPath: restoreJournalURL.path) {
            try FileManager.default.removeItem(at: restoreJournalURL)
        }
    }

    private func deleteRestoreJournalBestEffort() {
        try? deleteRestoreJournal()
    }

    private func validateIndexMode(_ mode: String) throws {
        guard mode == "100644" || mode == "100755" || mode == "120000" else {
            throw MCPServerError.operationFailed(
                "Checkpoint restore does not support Git index mode \(mode)"
            )
        }
    }

    private func ensurePathInsideRepo(repo: URL, full: URL) throws {
        let root = repo.standardizedFileURL.path
        let path = full.standardizedFileURL.path
        guard path != root, path.hasPrefix(root + "/") else {
            throw MCPServerError.invalidPath("Checkpoint restore path escaped repository")
        }
    }

    private func requireRegularOrMissing(_ url: URL, relativePath: String) throws -> Bool {
        var st = stat()
        if lstat(url.path, &st) != 0 {
            if errno == ENOENT { return false }
            throw MCPServerError.operationFailed(
                "Checkpoint restore could not inspect target: \(relativePath)"
            )
        }
        let kind = st.st_mode & S_IFMT
        if kind == S_IFLNK {
            throw MCPServerError.invalidPath(
                "Checkpoint restore refuses symlink/reparse target: \(relativePath)"
            )
        }
        guard kind == S_IFREG else {
            throw MCPServerError.invalidPath(
                "Checkpoint restore only mutates regular files: \(relativePath)"
            )
        }
        return true
    }

    private func restoreResult(
        checkpointRef: String,
        state: String,
        repoRelative: String,
        historyMode: String,
        originalHead: String?,
        targetHead: String?,
        rollbackRef: String?,
        plan: CheckpointRestorePlan,
        recoveredIncomplete: Bool,
        error: String? = nil,
        rollbackError: String? = nil
    ) -> [String: Any] {
        [
            "checkpoint_ref": checkpointRef,
            "state": state,
            "repository_relative_path": repoRelative,
            "history_mode": historyMode,
            "original_head_oid": originalHead.map { $0 as Any } ?? NSNull(),
            "target_head_oid": targetHead.map { $0 as Any } ?? NSNull(),
            "rollback_checkpoint_ref": rollbackRef.map { $0 as Any } ?? NSNull(),
            "path_count": plan.paths.count,
            "skipped_count": plan.skippedCount,
            "recovered_incomplete": recoveredIncomplete,
            "error": error.map { $0 as Any } ?? NSNull(),
            "rollback_error": rollbackError.map { $0 as Any } ?? NSNull(),
        ]
    }
}


// FMG-022 transactional checkpoint restore. Kept in the capture service so the
// authenticated manifest/index store and rollback checkpoint lifecycle have one owner.
private final class CheckpointRestorePlan {
    var paths: [CheckpointRestorePathPlan] = []
    var hasIndexSkips = false
    var hasWorktreeSkips = false
    var skippedCount = 0
}

private final class CheckpointRestorePathPlan {
    let relativePath: String
    var skipIndex = false
    var skipWorktree = false
    var skipReason: String?
    var desiredIndexExists = false
    var desiredIndexMode: String?
    var desiredIndexOID: String?
    var desiredIndexBytes: Data?
    var desiredWorktreeExists = false
    var desiredWorktreeBytes: Data?
    var desiredWorktreeSHA256: String?
    var desiredWorktreeMode: String?
    var currentWorktreeExists = false
    var needsWorktreeMutation = false
    var worktreeGuard: AuthorizedPathSnapshot?

    init(relativePath: String) {
        self.relativePath = relativePath
    }
}

private struct CheckpointGitTreeEntry {
    let mode: String
    let type: String
    let oid: String
}

private struct CheckpointRestoreJournal: Codable {
    var transactionId: String
    var phase: String
    var targetCheckpointRef: String
    var rollbackCheckpointRef: String
    var repositoryRelativePath: String
    var originalHeadOid: String?
    var targetHeadOid: String?
    var historyMode: String
    var startedEpochMs: Int64
}

struct WorkspaceCheckpointCrashForTestsError: LocalizedError {
    let errorDescription: String? = "simulated checkpoint restore crash"
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
    let indexMode: String?
    let indexExcludedReason: String?
    let worktreeContentRef: String?
    let worktreeSha256: String?
    let worktreeSizeBytes: Int64
    let worktreeExcludedReason: String?
}
