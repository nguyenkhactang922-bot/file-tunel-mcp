import Foundation
import CryptoKit
import Darwin

enum QuarantineServiceError: LocalizedError {
    case invalid(String)
    case io(String)

    var errorDescription: String? {
        switch self {
        case let .invalid(message), let .io(message): return message
        }
    }
}

struct QuarantineServiceOptions {
    var metadataRootURL: URL?
    var defaultTTL: TimeInterval = 24 * 60 * 60
    var maxTTL: TimeInterval = 7 * 24 * 60 * 60
    var maxTreeEntries: Int = 10_000
    var maxTreeBytes: Int64 = 512 * 1024 * 1024
    var now: () -> Date = Date.init
    var faultInjector: ((String) -> Error?)?
}

final class QuarantineService {
    private static let schemaVersion = 1
    private static let maxSingleFileBytes = 64 * 1024 * 1024

    private let resolver: SafePathResolver
    private let versions: FileVersionService
    private let mutationGuard: AuthorizedPathSnapshotService
    private let artifactFactory: () throws -> ArtifactContentStore
    private let policy: ServerPolicy
    private let options: QuarantineServiceOptions
    private let workspaceAuthorityID: String
    private let metadataRootURL: URL
    private let indexURL: URL
    private let stageForTests: ((String) -> Void)?
    private let lock = NSLock()

    private var records: [QuarantineRecord]

    convenience init(
        resolver: SafePathResolver,
        versions: FileVersionService,
        mutationGuard: AuthorizedPathSnapshotService,
        artifacts: ArtifactContentStore,
        policy: ServerPolicy,
        options: QuarantineServiceOptions = QuarantineServiceOptions(),
        stageForTests: ((String) -> Void)? = nil
    ) throws {
        try self.init(
            resolver: resolver,
            versions: versions,
            mutationGuard: mutationGuard,
            artifactFactory: { artifacts },
            policy: policy,
            options: options,
            stageForTests: stageForTests
        )
    }

    init(
        resolver: SafePathResolver,
        versions: FileVersionService,
        mutationGuard: AuthorizedPathSnapshotService,
        artifactFactory: @escaping () throws -> ArtifactContentStore,
        policy: ServerPolicy,
        options: QuarantineServiceOptions = QuarantineServiceOptions(),
        stageForTests: ((String) -> Void)? = nil
    ) throws {
        try Self.validateOptions(options)
        self.resolver = resolver
        self.versions = versions
        self.mutationGuard = mutationGuard
        self.artifactFactory = artifactFactory
        self.policy = policy
        self.options = options
        self.stageForTests = stageForTests
        self.workspaceAuthorityID = ArtifactContentStore.workspaceAuthorityID(resolver.root)

        let base: URL
        if let configured = options.metadataRootURL {
            base = configured.standardizedFileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
            base = support.appendingPathComponent("FileMCP/quarantine-v1", isDirectory: true).standardizedFileURL
        }
        let suffix = String(workspaceAuthorityID.dropFirst("sha256:".count))
        self.metadataRootURL = base.appendingPathComponent(suffix, isDirectory: true)
        self.indexURL = self.metadataRootURL.appendingPathComponent("index-v1.json")

        try Self.hardenDirectory(self.metadataRootURL)
        self.records = try Self.loadIndex(self.indexURL)
        try self.records.forEach(Self.validateRecord)
    }

    private func artifacts() throws -> ArtifactContentStore {
        try artifactFactory()
    }

    func delete(
        relativePath: String,
        expectedVersion: String,
        dryRun: Bool,
        ttlSeconds: Int,
        preparedPolicy: PolicySnapshot,
        executionContext: ToolExecutionContext?
    ) throws -> [String: Any] {
        try requireContinuation(executionContext)
        let target = try resolver.resolveForDeletion(relativePath)
        guard target.path != resolver.root.path else {
            throw QuarantineServiceError.invalid("Refusing to quarantine-delete the shared root directory")
        }

        let mode = try fileModeNoFollow(target, missingMessage: "No such path: \(relativePath)")
        let kind = mode & S_IFMT
        guard kind != S_IFLNK else {
            throw QuarantineServiceError.invalid("quarantine_delete does not accept symlink targets")
        }
        let ttl = try resolveTTL(ttlSeconds)

        if kind == S_IFDIR {
            let snapshot = try captureTree(originalRelativePath: relativePath, rootURL: target, context: executionContext)
            if dryRun {
                return deletePreview(
                    relativePath: relativePath,
                    sourceVersion: snapshot.sourceVersion,
                    isTree: true,
                    entryCount: snapshot.entries.count,
                    totalBytes: snapshot.totalBytes,
                    ttl: ttl
                )
            }
            let normalized = try requireExpectedVersion(expectedVersion)
            guard snapshot.sourceVersion == normalized else {
                throw QuarantineServiceError.invalid("Directory tree changed since the expected quarantine version was captured")
            }
            let guardSnapshot = try mutationGuard.captureExisting(relativePath: relativePath)
            return try deleteTree(
                relativePath: relativePath,
                target: target,
                snapshot: snapshot,
                guardSnapshot: guardSnapshot,
                ttl: ttl,
                preparedPolicy: preparedPolicy,
                context: executionContext
            )
        }

        guard kind == S_IFREG else {
            throw QuarantineServiceError.invalid("quarantine_delete only supports regular files and real directories")
        }
        let read = try versions.readVersioned(relativePath: relativePath, maxBytes: Self.maxSingleFileBytes)
        if dryRun {
            return deletePreview(
                relativePath: relativePath,
                sourceVersion: read.versionToken,
                isTree: false,
                entryCount: 1,
                totalBytes: read.sizeBytes,
                ttl: ttl
            )
        }

        let normalized = try requireExpectedVersion(expectedVersion)
        let expectedRead = try versions.readExpectedVersioned(
            relativePath: relativePath,
            token: normalized,
            maxBytes: Self.maxSingleFileBytes
        )
        let guardSnapshot = try mutationGuard.captureExisting(relativePath: relativePath)
        return try deleteFile(
            relativePath: relativePath,
            target: target,
            source: expectedRead,
            guardSnapshot: guardSnapshot,
            ttl: ttl,
            preparedPolicy: preparedPolicy,
            context: executionContext
        )
    }

    func list(maxItems: Int) throws -> [String: Any] {
        guard maxItems > 0, maxItems <= 1000 else {
            throw QuarantineServiceError.invalid("max_items must be between 1 and 1000")
        }
        return try withLock {
            let nowMs = epochMs(options.now())
            let items = records
                .filter { $0.workspaceAuthorityID == workspaceAuthorityID }
                .sorted { $0.createdEpochMs > $1.createdEpochMs }
                .prefix(maxItems)
                .map { recordMetadata($0, expired: $0.expiresEpochMs <= nowMs, manifest: nil) }
            return [
                "items": Array(items),
                "count": items.count,
                "workspace_authority_id": workspaceAuthorityID,
            ]
        }
    }

    func get(quarantineRef: String) throws -> [String: Any] {
        let loaded = try loadRecordAndManifest(quarantineRef)
        return recordMetadata(loaded.record, expired: false, manifest: loaded.manifest)
    }

    func restore(
        quarantineRef: String,
        targetRelativePath: String,
        replaceExisting: Bool,
        expectedTargetVersion: String,
        preparedPolicy: PolicySnapshot,
        executionContext: ToolExecutionContext?
    ) throws -> [String: Any] {
        try requireContinuation(executionContext)
        let loaded = try loadRecordAndManifest(quarantineRef)
        guard loaded.record.state != "restored" else {
            throw QuarantineServiceError.invalid("Quarantine item was already restored")
        }

        let targetRelative = targetRelativePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? loaded.manifest.originalRelativePath
            : targetRelativePath.trimmingCharacters(in: .whitespacesAndNewlines)

        if loaded.manifest.isTree {
            guard !replaceExisting else {
                throw QuarantineServiceError.invalid("Tree restore requires an absent destination; replace_existing is not supported for directory trees")
            }
            return try restoreTree(
                record: loaded.record,
                manifest: loaded.manifest,
                targetRelative: targetRelative,
                preparedPolicy: preparedPolicy,
                context: executionContext
            )
        }

        return try restoreFile(
            record: loaded.record,
            manifest: loaded.manifest,
            targetRelative: targetRelative,
            replaceExisting: replaceExisting,
            expectedTargetVersion: expectedTargetVersion,
            preparedPolicy: preparedPolicy,
            context: executionContext
        )
    }

    private func deleteFile(
        relativePath: String,
        target: URL,
        source: FileVersionedRead,
        guardSnapshot: AuthorizedPathSnapshot,
        ttl: TimeInterval,
        preparedPolicy: PolicySnapshot,
        context: ToolExecutionContext?
    ) throws -> [String: Any] {
        var createdRefs: [String] = []
        var record: QuarantineRecord?
        var deleteCommitStarted = false

        do {
            try requireContinuation(context)
            let payload = try artifacts().put(
                data: source.data,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClass: ArtifactContentClass.quarantine.rawValue,
                mediaType: "application/octet-stream",
                ttl: ttl
            )
            createdRefs.append(payload.contentRef)
            guard payload.blobID == source.contentHash else {
                throw QuarantineServiceError.invalid("Quarantine payload digest does not match the strong source version")
            }

            let now = options.now()
            let manifest = QuarantineManifest(
                schemaVersion: Self.schemaVersion,
                originalRelativePath: relativePath,
                sourceVersion: source.versionToken,
                isTree: false,
                createdEpochMs: epochMs(now),
                expiresEpochMs: epochMs(now.addingTimeInterval(ttl)),
                entries: [
                    QuarantineManifestEntry(
                        relativePath: "",
                        entryType: "file",
                        sizeBytes: source.sizeBytes,
                        sha256: source.contentHash,
                        contentRef: payload.contentRef
                    )
                ]
            )
            let packaged = try storeManifest(manifest, ttl: ttl, createdRefs: &createdRefs)
            var durable = newRecord(packaged: packaged, manifest: manifest)
            try addRecord(durable)
            record = durable
            try verifyPackage(record: durable, manifest: manifest)

            stageForTests?("after_package_verified")
            try policy.authorize("quarantine_delete", prepared: preparedPolicy)
            _ = try mutationGuard.verify(guardSnapshot)
            _ = try versions.verifyExpectedVersion(
                relativePath: relativePath,
                token: source.versionToken,
                maxBytes: Self.maxSingleFileBytes
            )
            try requireContinuation(context)
            deleteCommitStarted = true
            try FileManager.default.removeItem(at: target)
            durable.state = "quarantined"
            try replaceRecord(durable)
            return deleteResult(record: durable, manifest: manifest)
        } catch {
            if !deleteCommitStarted {
                if let record { try? removeRecord(record.quarantineRef) }
                deleteRefsBestEffort(createdRefs)
            }
            throw error
        }
    }

    private func deleteTree(
        relativePath: String,
        target: URL,
        snapshot: TreeSnapshot,
        guardSnapshot: AuthorizedPathSnapshot,
        ttl: TimeInterval,
        preparedPolicy: PolicySnapshot,
        context: ToolExecutionContext?
    ) throws -> [String: Any] {
        var createdRefs: [String] = []
        var record: QuarantineRecord?
        var deleteCommitStarted = false

        do {
            var manifestEntries: [QuarantineManifestEntry] = []
            for entry in snapshot.entries {
                try requireContinuation(context)
                if entry.entryType == "directory" {
                    manifestEntries.append(QuarantineManifestEntry(
                        relativePath: entry.relativePath,
                        entryType: "directory",
                        sizeBytes: 0,
                        sha256: "",
                        contentRef: nil
                    ))
                    continue
                }
                guard let input = InputStream(url: entry.absoluteURL) else {
                    throw QuarantineServiceError.io("Could not open quarantine tree payload")
                }
                let payload = try artifacts().put(
                    input: input,
                    workspaceAuthorityID: workspaceAuthorityID,
                    contentClass: ArtifactContentClass.quarantine.rawValue,
                    mediaType: "application/octet-stream",
                    ttl: ttl
                )
                createdRefs.append(payload.contentRef)
                guard payload.blobID == entry.sha256 else {
                    throw QuarantineServiceError.invalid("Quarantine package detected a changed tree file: \(entry.relativePath)")
                }
                manifestEntries.append(QuarantineManifestEntry(
                    relativePath: entry.relativePath,
                    entryType: "file",
                    sizeBytes: entry.sizeBytes,
                    sha256: entry.sha256,
                    contentRef: payload.contentRef
                ))
            }

            let finalSnapshot = try captureTree(originalRelativePath: relativePath, rootURL: target, context: context)
            guard finalSnapshot.sourceVersion == snapshot.sourceVersion else {
                throw QuarantineServiceError.invalid("Directory tree changed while the quarantine package was being captured")
            }

            let now = options.now()
            let manifest = QuarantineManifest(
                schemaVersion: Self.schemaVersion,
                originalRelativePath: relativePath,
                sourceVersion: snapshot.sourceVersion,
                isTree: true,
                createdEpochMs: epochMs(now),
                expiresEpochMs: epochMs(now.addingTimeInterval(ttl)),
                entries: manifestEntries
            )
            let packaged = try storeManifest(manifest, ttl: ttl, createdRefs: &createdRefs)
            let durable = newRecord(packaged: packaged, manifest: manifest)
            try addRecord(durable)
            record = durable
            try verifyPackage(record: durable, manifest: manifest)

            stageForTests?("after_package_verified")
            try policy.authorize("quarantine_delete", prepared: preparedPolicy)
            _ = try mutationGuard.verify(guardSnapshot)
            let commitSnapshot = try captureTree(originalRelativePath: relativePath, rootURL: target, context: context)
            guard commitSnapshot.sourceVersion == snapshot.sourceVersion else {
                throw QuarantineServiceError.invalid("Directory tree changed before quarantine deletion could commit")
            }
            try requireContinuation(context)
            deleteCommitStarted = true
            try FileManager.default.removeItem(at: target)
            var completed = durable
            completed.state = "quarantined"
            try replaceRecord(completed)
            return deleteResult(record: completed, manifest: manifest)
        } catch {
            if !deleteCommitStarted {
                if let record { try? removeRecord(record.quarantineRef) }
                deleteRefsBestEffort(createdRefs)
            }
            throw error
        }
    }

    private func restoreFile(
        record inputRecord: QuarantineRecord,
        manifest: QuarantineManifest,
        targetRelative: String,
        replaceExisting: Bool,
        expectedTargetVersion: String,
        preparedPolicy: PolicySnapshot,
        context: ToolExecutionContext?
    ) throws -> [String: Any] {
        guard manifest.entries.count == 1,
              let entry = manifest.entries.first,
              entry.entryType == "file",
              let contentRef = entry.contentRef else {
            throw QuarantineServiceError.invalid("Quarantine file manifest is invalid")
        }

        let target = try resolver.resolve(targetRelative)
        let exists = entryExists(target)
        let guardSnapshot: AuthorizedPathSnapshot
        var normalizedTargetVersion: String?

        if exists {
            guard replaceExisting else {
                throw QuarantineServiceError.invalid("Restore destination already exists; replace_existing must be explicit")
            }
            let normalized = try requireExpectedVersion(expectedTargetVersion)
            _ = try versions.verifyExpectedVersion(
                relativePath: targetRelative,
                token: normalized,
                maxBytes: Self.maxSingleFileBytes
            )
            normalizedTargetVersion = normalized
            guardSnapshot = try mutationGuard.captureExisting(relativePath: targetRelative)
        } else {
            guard !replaceExisting else {
                throw QuarantineServiceError.invalid("replace_existing requested but restore destination is absent")
            }
            guardSnapshot = try mutationGuard.captureNewTarget(relativePath: targetRelative)
        }

        stageForTests?("after_restore_plan")
        let parent = target.deletingLastPathComponent()
        guard entryExists(parent) else {
            throw QuarantineServiceError.invalid("Restore destination parent must already exist")
        }

        let temp = parent.appendingPathComponent(".\(target.lastPathComponent).filemcp-restore-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temp) }

        guard let output = OutputStream(url: temp, append: false) else {
            throw QuarantineServiceError.io("Could not create restore staging stream")
        }
        try artifacts().copy(
            contentRef,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: { $0 == ArtifactContentClass.quarantine.rawValue },
            to: output
        )
        try verifyRestoredFile(temp, entry: entry)

        try policy.authorize("quarantine_restore", prepared: preparedPolicy)
        _ = try mutationGuard.verify(guardSnapshot)
        if let normalizedTargetVersion {
            _ = try versions.verifyExpectedVersion(
                relativePath: targetRelative,
                token: normalizedTargetVersion,
                maxBytes: Self.maxSingleFileBytes
            )
        }
        try requireContinuation(context)

        if exists {
            _ = try FileManager.default.replaceItemAt(target, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: target)
        }
        try verifyRestoredFile(target, entry: entry)

        var record = inputRecord
        record.state = "restored"
        record.lastRestoreTarget = targetRelative
        record.recoveryContentRef = nil
        try replaceRecord(record)
        return restoreResult(record: record, state: "restored", target: targetRelative, recoveryRef: nil)
    }

    private func restoreTree(
        record inputRecord: QuarantineRecord,
        manifest: QuarantineManifest,
        targetRelative: String,
        preparedPolicy: PolicySnapshot,
        context: ToolExecutionContext?
    ) throws -> [String: Any] {
        let target = try resolver.resolve(targetRelative)
        guard !entryExists(target) else {
            throw QuarantineServiceError.invalid("Tree restore destination must be absent")
        }

        let rootGuard = try mutationGuard.captureNewTarget(relativePath: targetRelative)
        stageForTests?("after_restore_plan")
        let rollback = try createRollbackCheckpoint(record: inputRecord, targetRelative: targetRelative)
        var record = inputRecord
        record.recoveryContentRef = rollback.contentRef
        try replaceRecord(record)

        var createdRootGuard: AuthorizedPathSnapshot?
        do {
            try policy.authorize("quarantine_restore", prepared: preparedPolicy)
            _ = try mutationGuard.verify(rootGuard)
            try requireContinuation(context)
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            createdRootGuard = try mutationGuard.captureExisting(relativePath: targetRelative)

            for directory in manifest.entries
                .filter({ $0.entryType == "directory" })
                .sorted(by: {
                    let ld = pathDepth($0.relativePath)
                    let rd = pathDepth($1.relativePath)
                    return ld == rd ? $0.relativePath < $1.relativePath : ld < rd
                }) {
                try requireContinuation(context)
                let relativeChild = joinRelative(targetRelative, directory.relativePath)
                let child = try resolver.resolve(relativeChild)
                guard !entryExists(child) else {
                    throw QuarantineServiceError.invalid("Tree restore destination appeared unexpectedly: \(relativeChild)")
                }
                try FileManager.default.createDirectory(at: child, withIntermediateDirectories: false)
            }

            for file in manifest.entries.filter({ $0.entryType == "file" }).sorted(by: { $0.relativePath < $1.relativePath }) {
                try requireContinuation(context)
                let relativeChild = joinRelative(targetRelative, file.relativePath)
                let child = try resolver.resolve(relativeChild)
                let childGuard = try mutationGuard.captureNewTarget(relativePath: relativeChild)
                let parent = child.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

                let temp = parent.appendingPathComponent(".\(child.lastPathComponent).filemcp-restore-\(UUID().uuidString).tmp")
                defer { try? FileManager.default.removeItem(at: temp) }
                guard let contentRef = file.contentRef,
                      let output = OutputStream(url: temp, append: false) else {
                    throw QuarantineServiceError.invalid("Tree manifest file payload is missing")
                }
                try artifacts().copy(
                    contentRef,
                    workspaceAuthorityID: workspaceAuthorityID,
                    contentClassAllowed: { $0 == ArtifactContentClass.quarantine.rawValue },
                    to: output
                )
                try verifyRestoredFile(temp, entry: file)
                try policy.authorize("quarantine_restore", prepared: preparedPolicy)
                _ = try mutationGuard.verify(childGuard)
                try requireContinuation(context)
                try FileManager.default.moveItem(at: temp, to: child)
                try verifyRestoredFile(child, entry: file)
                stageForTests?("after_tree_publish:\(file.relativePath)")
            }

            try verifyRestoredTree(targetRelative: targetRelative, target: target, manifest: manifest, context: context)
            _ = try artifacts().delete(
                rollback.contentRef,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClassAllowed: { $0 == ArtifactContentClass.checkpoint.rawValue }
            )
            record.recoveryContentRef = nil
            record.state = "restored"
            record.lastRestoreTarget = targetRelative
            try replaceRecord(record)
            return restoreResult(record: record, state: "restored", target: targetRelative, recoveryRef: nil)
        } catch {
            let restoreError = error
            do {
                stageForTests?("before_tree_rollback")
                if let createdRootGuard {
                    _ = try mutationGuard.verify(createdRootGuard)
                    if entryExists(target) {
                        try FileManager.default.removeItem(at: target)
                    }
                    guard !entryExists(target) else {
                        throw QuarantineServiceError.invalid("Tree rollback could not remove the partially restored destination")
                    }
                }
                _ = try artifacts().delete(
                    rollback.contentRef,
                    workspaceAuthorityID: workspaceAuthorityID,
                    contentClassAllowed: { $0 == ArtifactContentClass.checkpoint.rawValue }
                )
                record.recoveryContentRef = nil
                record.state = "rolled_back"
                record.lastRestoreTarget = targetRelative
                try replaceRecord(record)
                return restoreResult(
                    record: record,
                    state: "rolled_back",
                    target: targetRelative,
                    recoveryRef: nil,
                    error: restoreError.localizedDescription
                )
            } catch {
                let rollbackError = error
                record.state = "partial_recovery_required"
                record.lastRestoreTarget = targetRelative
                record.recoveryContentRef = rollback.contentRef
                try? replaceRecord(record)
                return restoreResult(
                    record: record,
                    state: "partial_recovery_required",
                    target: targetRelative,
                    recoveryRef: rollback.contentRef,
                    error: restoreError.localizedDescription,
                    rollbackError: rollbackError.localizedDescription
                )
            }
        }
    }

    private func captureTree(
        originalRelativePath: String,
        rootURL: URL,
        context: ToolExecutionContext?
    ) throws -> TreeSnapshot {
        let rootMode = try fileModeNoFollow(rootURL, missingMessage: "No such directory: \(originalRelativePath)")
        guard rootMode & S_IFMT == S_IFDIR else {
            throw QuarantineServiceError.invalid("Quarantine tree source must be a real directory, not a symlink")
        }

        var entries: [TreeEntry] = []
        var totalBytes: Int64 = 0
        var pending: [(URL, String)] = [(rootURL, "")]

        while let current = pending.popLast() {
            try requireContinuation(context)
            let children = try FileManager.default.contentsOfDirectory(
                at: current.0,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
                options: []
            ).sorted { $0.lastPathComponent < $1.lastPathComponent }

            for child in children {
                try requireContinuation(context)
                guard entries.count < options.maxTreeEntries else {
                    throw QuarantineServiceError.invalid("Quarantine tree exceeds the \(options.maxTreeEntries) entry limit")
                }
                let mode = try fileModeNoFollow(child, missingMessage: "Quarantine tree entry disappeared")
                let kind = mode & S_IFMT
                guard kind != S_IFLNK else {
                    throw QuarantineServiceError.invalid("Quarantine tree refuses symlink descendants")
                }
                let rel = current.1.isEmpty ? child.lastPathComponent : current.1 + "/" + child.lastPathComponent

                if kind == S_IFDIR {
                    entries.append(TreeEntry(
                        relativePath: rel,
                        absoluteURL: child,
                        entryType: "directory",
                        sizeBytes: 0,
                        sha256: ""
                    ))
                    pending.append((child, rel))
                    continue
                }
                guard kind == S_IFREG else {
                    throw QuarantineServiceError.invalid("Quarantine tree contains an unsupported entry type: \(rel)")
                }
                let attrs = try FileManager.default.attributesOfItem(atPath: child.path)
                let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                totalBytes = try checkedAdd(totalBytes, size)
                guard totalBytes <= options.maxTreeBytes else {
                    throw QuarantineServiceError.invalid("Quarantine tree exceeds the configured total-byte limit")
                }
                guard size <= Int64(Self.maxSingleFileBytes) else {
                    throw QuarantineServiceError.invalid("Quarantine tree file exceeds the per-file limit: \(rel)")
                }
                let hash = try hashFile(child, context: context)
                entries.append(TreeEntry(
                    relativePath: rel,
                    absoluteURL: child,
                    entryType: "file",
                    sizeBytes: size,
                    sha256: hash
                ))
            }
        }

        entries.sort {
            if $0.relativePath == $1.relativePath { return $0.entryType < $1.entryType }
            return $0.relativePath < $1.relativePath
        }
        let canonical = canonicalTreeString(path: originalRelativePath, entries: entries.map {
            QuarantineManifestEntry(
                relativePath: $0.relativePath,
                entryType: $0.entryType,
                sizeBytes: $0.sizeBytes,
                sha256: $0.sha256,
                contentRef: nil
            )
        })
        return TreeSnapshot(
            sourceVersion: "tree-" + FileVersionService.sha256Tagged(Data(canonical.utf8)),
            entries: entries,
            totalBytes: totalBytes
        )
    }

    private func hashFile(_ url: URL, context: ToolExecutionContext?) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            try requireContinuation(context)
            let chunk = try handle.read(upToCount: 128 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return "sha256:" + hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func storeManifest(
        _ manifest: QuarantineManifest,
        ttl: TimeInterval,
        createdRefs: inout [String]
    ) throws -> (descriptor: ArtifactContentDescriptor, manifestHash: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        let hash = FileVersionService.sha256Tagged(data)
        let descriptor = try artifacts().put(
            data: data,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClass: ArtifactContentClass.quarantine.rawValue,
            mediaType: "application/vnd.filemcp.quarantine-manifest+json",
            ttl: ttl
        )
        createdRefs.append(descriptor.contentRef)
        guard descriptor.blobID == hash else {
            throw QuarantineServiceError.invalid("Quarantine manifest digest mismatch")
        }
        return (descriptor, hash)
    }

    private func newRecord(
        packaged: (descriptor: ArtifactContentDescriptor, manifestHash: String),
        manifest: QuarantineManifest
    ) -> QuarantineRecord {
        QuarantineRecord(
            quarantineRef: packaged.descriptor.contentRef,
            workspaceAuthorityID: workspaceAuthorityID,
            originalRelativePath: manifest.originalRelativePath,
            sourceVersion: manifest.sourceVersion,
            manifestHash: packaged.manifestHash,
            isTree: manifest.isTree,
            createdEpochMs: packaged.descriptor.createdEpochMs,
            expiresEpochMs: packaged.descriptor.expiresEpochMs,
            state: "prepared",
            lastRestoreTarget: nil,
            recoveryContentRef: nil
        )
    }

    private func verifyPackage(record: QuarantineRecord, manifest: QuarantineManifest) throws {
        let descriptor = try artifacts().resolve(
            record.quarantineRef,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: { $0 == ArtifactContentClass.quarantine.rawValue }
        )
        guard descriptor.blobID == record.manifestHash else {
            throw QuarantineServiceError.invalid("Quarantine manifest blob does not match recorded manifest hash")
        }

        for entry in manifest.entries where entry.entryType == "file" {
            guard let contentRef = entry.contentRef else {
                throw QuarantineServiceError.invalid("Quarantine manifest file payload is missing")
            }
            let payload = try artifacts().resolve(
                contentRef,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClassAllowed: { $0 == ArtifactContentClass.quarantine.rawValue }
            )
            guard payload.blobID == entry.sha256, payload.sizeBytes == entry.sizeBytes else {
                throw QuarantineServiceError.invalid("Quarantine payload verification failed: \(entry.relativePath)")
            }
        }
    }

    private func loadRecordAndManifest(_ quarantineRef: String) throws -> (record: QuarantineRecord, manifest: QuarantineManifest) {
        let trimmed = quarantineRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw QuarantineServiceError.invalid("quarantine_ref is required")
        }
        let record = try withLock {
            guard let found = records.first(where: {
                $0.workspaceAuthorityID == workspaceAuthorityID && $0.quarantineRef == trimmed
            }) else {
                throw QuarantineServiceError.invalid("QuarantineRef is unavailable")
            }
            return found
        }
        guard record.expiresEpochMs > epochMs(options.now()) else {
            throw QuarantineServiceError.invalid("QuarantineRef expired")
        }

        let descriptor = try artifacts().resolve(
            trimmed,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: { $0 == ArtifactContentClass.quarantine.rawValue }
        )
        guard descriptor.blobID == record.manifestHash else {
            throw QuarantineServiceError.invalid("QuarantineRef metadata does not match its authenticated manifest")
        }

        let output = OutputStream.toMemory()
        try artifacts().copy(
            trimmed,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: { $0 == ArtifactContentClass.quarantine.rawValue },
            to: output
        )
        guard let data = output.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
            throw QuarantineServiceError.io("Quarantine manifest stream is unavailable")
        }
        guard FileVersionService.sha256Tagged(data) == record.manifestHash else {
            throw QuarantineServiceError.invalid("Quarantine manifest content is corrupt")
        }
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(QuarantineManifest.self, from: data)
        try Self.validateManifest(manifest)
        guard manifest.originalRelativePath == record.originalRelativePath,
              manifest.sourceVersion == record.sourceVersion,
              manifest.isTree == record.isTree else {
            throw QuarantineServiceError.invalid("Quarantine metadata/manifest mismatch")
        }
        return (record, manifest)
    }

    private func createRollbackCheckpoint(
        record: QuarantineRecord,
        targetRelative: String
    ) throws -> ArtifactContentDescriptor {
        let object: [String: Any] = [
            "schema_version": 1,
            "kind": "quarantine-tree-rollback",
            "target_relative_path": targetRelative,
            "target_expected_absent": true,
            "quarantine_ref": record.quarantineRef,
            "manifest_hash": record.manifestHash,
            "created_epoch_ms": epochMs(options.now()),
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return try artifacts().put(
            data: data,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClass: ArtifactContentClass.checkpoint.rawValue,
            mediaType: "application/vnd.filemcp.rollback-checkpoint+json",
            ttl: 24 * 60 * 60
        )
    }

    private func verifyRestoredTree(
        targetRelative: String,
        target: URL,
        manifest: QuarantineManifest,
        context: ToolExecutionContext?
    ) throws {
        let captured = try captureTree(originalRelativePath: targetRelative, rootURL: target, context: context)
        let expectedCanonical = canonicalTreeString(path: targetRelative, entries: manifest.entries)
        let expectedVersion = "tree-" + FileVersionService.sha256Tagged(Data(expectedCanonical.utf8))
        guard captured.sourceVersion == expectedVersion else {
            throw QuarantineServiceError.invalid("Restored tree failed final manifest verification")
        }
    }

    private func verifyRestoredFile(_ url: URL, entry: QuarantineManifestEntry) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? -1
        guard size == entry.sizeBytes else {
            throw QuarantineServiceError.invalid("Restored file failed size verification")
        }
        let hashed = try FileVersionService.sha256File(url, maxBytes: max(Int64(1), entry.sizeBytes))
        guard hashed.bytesRead == entry.sizeBytes, hashed.hash == entry.sha256 else {
            throw QuarantineServiceError.invalid("Restored file failed digest verification")
        }
    }

    private func addRecord(_ record: QuarantineRecord) throws {
        try withLock {
            guard !records.contains(where: { $0.quarantineRef == record.quarantineRef }) else {
                throw QuarantineServiceError.invalid("Duplicate quarantine reference")
            }
            var candidate = records
            candidate.append(record)
            try persist(candidate)
            records = candidate
        }
    }

    private func replaceRecord(_ record: QuarantineRecord) throws {
        try withLock {
            guard let index = records.firstIndex(where: { $0.quarantineRef == record.quarantineRef }) else {
                throw QuarantineServiceError.invalid("QuarantineRef is unavailable")
            }
            var candidate = records
            candidate[index] = record
            try persist(candidate)
            records = candidate
        }
    }

    private func removeRecord(_ quarantineRef: String) throws {
        try withLock {
            let candidate = records.filter { $0.quarantineRef != quarantineRef }
            try persist(candidate)
            records = candidate
        }
    }

    private func persist(_ candidate: [QuarantineRecord]) throws {
        if let error = options.faultInjector?("before-index-commit") { throw error }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(QuarantineIndex(schemaVersion: Self.schemaVersion, records: candidate))
        try data.write(to: indexURL, options: .atomic)
        _ = indexURL.path.withCString { chmod($0, mode_t(S_IRUSR | S_IWUSR)) }
    }

    private func deleteRefsBestEffort(_ refs: [String]) {
        for contentRef in refs.reversed() {
            _ = try? artifacts().delete(
                contentRef,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClassAllowed: {
                    $0 == ArtifactContentClass.quarantine.rawValue ||
                    $0 == ArtifactContentClass.checkpoint.rawValue
                }
            )
        }
    }

    private func deletePreview(
        relativePath: String,
        sourceVersion: String,
        isTree: Bool,
        entryCount: Int,
        totalBytes: Int64,
        ttl: TimeInterval
    ) -> [String: Any] {
        [
            "dry_run": true,
            "relative_path": relativePath,
            "source_version": sourceVersion,
            "is_tree": isTree,
            "entry_count": entryCount,
            "total_bytes": totalBytes,
            "ttl_seconds": Int(ttl),
        ]
    }

    private func deleteResult(record: QuarantineRecord, manifest: QuarantineManifest) -> [String: Any] {
        [
            "dry_run": false,
            "quarantine_ref": record.quarantineRef,
            "original_relative_path": record.originalRelativePath,
            "source_version": record.sourceVersion,
            "manifest_hash": record.manifestHash,
            "expires_epoch_ms": record.expiresEpochMs,
            "is_tree": record.isTree,
            "entry_count": manifest.entries.count,
            "state": record.state,
        ]
    }

    private func restoreResult(
        record: QuarantineRecord,
        state: String,
        target: String,
        recoveryRef: String?,
        error: String? = nil,
        rollbackError: String? = nil
    ) -> [String: Any] {
        var result: [String: Any] = [
            "quarantine_ref": record.quarantineRef,
            "state": state,
            "target_relative_path": target,
        ]
        if let recoveryRef, !recoveryRef.isEmpty {
            result["recovery_ref"] = recoveryRef
        }
        if let error, !error.isEmpty {
            result["restore_error"] = error
        }
        if let rollbackError, !rollbackError.isEmpty {
            result["rollback_error"] = rollbackError
        }
        return result
    }

    private func recordMetadata(
        _ record: QuarantineRecord,
        expired: Bool,
        manifest: QuarantineManifest? = nil
    ) -> [String: Any] {
        var result: [String: Any] = [
            "quarantine_ref": record.quarantineRef,
            "original_relative_path": record.originalRelativePath,
            "source_version": record.sourceVersion,
            "manifest_hash": record.manifestHash,
            "is_tree": record.isTree,
            "created_epoch_ms": record.createdEpochMs,
            "expires_epoch_ms": record.expiresEpochMs,
            "expired": expired,
            "state": record.state,
        ]
        if let lastRestoreTarget = record.lastRestoreTarget, !lastRestoreTarget.isEmpty {
            result["last_restore_target"] = lastRestoreTarget
        }
        if let recoveryContentRef = record.recoveryContentRef, !recoveryContentRef.isEmpty {
            result["recovery_ref"] = recoveryContentRef
        }
        if let manifest {
            result["entry_count"] = manifest.entries.count
            result["total_bytes"] = manifest.entries
                .filter { $0.entryType == "file" }
                .reduce(Int64(0)) { $0 + $1.sizeBytes }
        }
        return result
    }

    private func resolveTTL(_ ttlSeconds: Int) throws -> TimeInterval {
        let ttl = ttlSeconds <= 0 ? options.defaultTTL : TimeInterval(ttlSeconds)
        guard ttl > 0, ttl <= options.maxTTL else {
            throw QuarantineServiceError.invalid("Quarantine TTL must be positive and bounded")
        }
        return ttl
    }

    private func requireExpectedVersion(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw QuarantineServiceError.invalid(
                "expected_version is required unless quarantine_delete is a dry run"
            )
        }
        return trimmed
    }

    private func requireContinuation(_ context: ToolExecutionContext?) throws {
        guard let context else { return }
        guard context.tryContinue() else {
            throw QuarantineServiceError.invalid(
                "Quarantine operation aborted: \(context.truncationReason)"
            )
        }
    }

    private func canonicalTreeString(
        path: String,
        entries: [QuarantineManifestEntry]
    ) -> String {
        var value = "path=\(path.replacingOccurrences(of: "\\", with: "/"))\n"
        for entry in entries.sorted(by: {
            if $0.relativePath == $1.relativePath {
                return $0.entryType < $1.entryType
            }
            return $0.relativePath < $1.relativePath
        }) {
            value += "\(entry.entryType)|\(entry.relativePath)|\(entry.sizeBytes)|\(entry.sha256)\n"
        }
        return value
    }

    private func joinRelative(_ root: String, _ child: String) -> String {
        let normalizedRoot = root
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedChild = child
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalizedRoot.isEmpty
            ? normalizedChild
            : normalizedRoot + "/" + normalizedChild
    }

    private func pathDepth(_ path: String) -> Int {
        guard !path.isEmpty else { return 0 }
        return path.filter { $0 == "/" || $0 == "\\" }.count + 1
    }

    private func fileModeNoFollow(_ url: URL, missingMessage: String) throws -> mode_t {
        var info = stat()
        let result = url.path.withCString { lstat($0, &info) }
        guard result == 0 else {
            if errno == ENOENT || errno == ENOTDIR {
                throw QuarantineServiceError.invalid(missingMessage)
            }
            throw QuarantineServiceError.io(
                "Could not inspect \(url.lastPathComponent): \(String(cString: strerror(errno)))"
            )
        }
        return info.st_mode
    }

    private func entryExists(_ url: URL) -> Bool {
        var info = stat()
        return url.path.withCString { lstat($0, &info) } == 0
    }

    private func checkedAdd(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else {
            throw QuarantineServiceError.invalid("Quarantine tree byte count overflow")
        }
        return value
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private static func loadIndex(_ indexURL: URL) throws -> [QuarantineRecord] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: indexURL)
            let decoded = try JSONDecoder().decode(QuarantineIndex.self, from: data)
            guard decoded.schemaVersion == schemaVersion else {
                throw QuarantineServiceError.invalid(
                    "Unsupported quarantine metadata schema version"
                )
            }
            return decoded.records
        } catch let error as QuarantineServiceError {
            throw error
        } catch {
            throw QuarantineServiceError.invalid(
                "Quarantine metadata index is corrupt: \(error.localizedDescription)"
            )
        }
    }

    private static func hardenDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let chmodResult = url.path.withCString { chmod($0, mode_t(S_IRWXU)) }
        guard chmodResult == 0 else {
            throw QuarantineServiceError.io(
                "Could not restrict quarantine metadata directory permissions"
            )
        }
    }

    private static func validateOptions(_ options: QuarantineServiceOptions) throws {
        guard options.defaultTTL > 0,
              options.maxTTL > 0,
              options.defaultTTL <= options.maxTTL,
              options.maxTTL <= 30 * 24 * 60 * 60,
              options.maxTreeEntries > 0,
              options.maxTreeEntries <= 100_000,
              options.maxTreeBytes > 0 else {
            throw QuarantineServiceError.invalid(
                "Quarantine service options are invalid"
            )
        }
    }

    private static func validateRecord(_ record: QuarantineRecord) throws {
        guard !record.quarantineRef.isEmpty,
              !record.workspaceAuthorityID.isEmpty,
              !record.originalRelativePath.isEmpty,
              !record.sourceVersion.isEmpty,
              !record.manifestHash.isEmpty,
              record.createdEpochMs >= 0,
              record.expiresEpochMs > record.createdEpochMs,
              ["prepared", "quarantined", "restored", "rolled_back", "partial_recovery_required"]
                .contains(record.state) else {
            throw QuarantineServiceError.invalid(
                "Quarantine metadata record is invalid"
            )
        }
    }

    private static func validateManifest(_ manifest: QuarantineManifest) throws {
        guard manifest.schemaVersion == schemaVersion,
              !manifest.originalRelativePath.isEmpty,
              !manifest.sourceVersion.isEmpty,
              manifest.expiresEpochMs > manifest.createdEpochMs else {
            throw QuarantineServiceError.invalid("Quarantine manifest is invalid")
        }
        if !manifest.isTree && manifest.entries.count != 1 {
            throw QuarantineServiceError.invalid(
                "Quarantine manifest entry count is invalid"
            )
        }
        for entry in manifest.entries {
            guard ["file", "directory"].contains(entry.entryType) else {
                throw QuarantineServiceError.invalid(
                    "Quarantine manifest entry type is invalid"
                )
            }
            if entry.entryType == "file" {
                guard entry.sizeBytes >= 0,
                      !entry.sha256.isEmpty,
                      !(entry.contentRef ?? "").isEmpty else {
                    throw QuarantineServiceError.invalid(
                        "Quarantine manifest file entry is invalid"
                    )
                }
            }
        }
    }

    private func epochMs(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000.0).rounded(.towardZero))
    }

    private struct QuarantineIndex: Codable {
        let schemaVersion: Int
        var records: [QuarantineRecord]
    }

    private struct QuarantineRecord: Codable {
        let quarantineRef: String
        let workspaceAuthorityID: String
        let originalRelativePath: String
        let sourceVersion: String
        let manifestHash: String
        let isTree: Bool
        let createdEpochMs: Int64
        let expiresEpochMs: Int64
        var state: String
        var lastRestoreTarget: String?
        var recoveryContentRef: String?
    }

    private struct QuarantineManifest: Codable {
        let schemaVersion: Int
        let originalRelativePath: String
        let sourceVersion: String
        let isTree: Bool
        let createdEpochMs: Int64
        let expiresEpochMs: Int64
        var entries: [QuarantineManifestEntry]
    }

    private struct QuarantineManifestEntry: Codable {
        let relativePath: String
        let entryType: String
        let sizeBytes: Int64
        let sha256: String
        let contentRef: String?
    }

    private struct TreeEntry {
        let relativePath: String
        let absoluteURL: URL
        let entryType: String
        let sizeBytes: Int64
        let sha256: String
    }

    private struct TreeSnapshot {
        let sourceVersion: String
        let entries: [TreeEntry]
        let totalBytes: Int64
    }
}
