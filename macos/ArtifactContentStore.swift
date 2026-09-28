import Foundation
import Security
import CryptoKit

enum ArtifactContentClasses {
    static let toolOutput = "TOOL_OUTPUT"
    static let ptyOutput = "PTY_OUTPUT"
    static let checkpoint = "CHECKPOINT"
    static let quarantine = "QUARANTINE"
    static let all: Set<String> = [toolOutput, ptyOutput, checkpoint, quarantine]

    static func isKnown(_ value: String) -> Bool { all.contains(value) }
}

enum ArtifactContentClass: String, CaseIterable {
    case toolOutput = "TOOL_OUTPUT"
    case ptyOutput = "PTY_OUTPUT"
    case checkpoint = "CHECKPOINT"
    case quarantine = "QUARANTINE"

    static func isKnown(_ value: String) -> Bool {
        allCases.contains { $0.rawValue == value }
    }
}

struct ArtifactContentStoreOptions {
    var rootURL: URL?
    var workspaceRootForIsolation: URL?
    var maxItemBytes: Int64 = ArtifactContentStore.defaultMaxItemBytes
    var maxWorkspaceBytes: Int64 = ArtifactContentStore.defaultMaxWorkspaceBytes
    var maxGlobalBytes: Int64 = ArtifactContentStore.defaultMaxGlobalBytes
    var defaultTTL: TimeInterval = ArtifactContentStore.defaultTTL
    var maxTTL: TimeInterval = ArtifactContentStore.defaultMaxTTL
    var now: () -> Date = Date.init
    var faultInjector: ((String, Int64) -> Error?)?
}

enum ArtifactContentStoreError: LocalizedError {
    case invalid(String)
    case quota(String)
    case unavailable(String)
    case integrity(String)
    case io(String)

    var errorDescription: String? {
        switch self {
        case let .invalid(message),
             let .quota(message),
             let .unavailable(message),
             let .integrity(message),
             let .io(message):
            return message
        }
    }
}

struct ArtifactContentDescriptor {
    let contentRef: String
    let referenceID: String
    let blobID: String
    let sizeBytes: Int64
    let contentClass: String
    let mediaType: String
    let createdEpochMs: Int64
    let expiresEpochMs: Int64
    let leaseID: String?
    let leaseExpiresEpochMs: Int64?
}

struct ArtifactStoreUsage {
    let referenceCount: Int
    let blobCount: Int
    let globalBytes: Int64
    let workspaceBytes: Int64
}

struct ArtifactGCResult {
    let expiredReferencesRemoved: Int
    let orphanBlobsRemoved: Int
    let stagingFilesRemoved: Int
}

final class ArtifactContentStore {
    static let schemaVersion = 1
    static let defaultMaxItemBytes: Int64 = 64 * 1024 * 1024
    static let defaultMaxWorkspaceBytes: Int64 = 512 * 1024 * 1024
    static let defaultMaxGlobalBytes: Int64 = 2 * 1024 * 1024 * 1024
    static let defaultTTL: TimeInterval = 24 * 60 * 60
    static let defaultMaxTTL: TimeInterval = 7 * 24 * 60 * 60

    private static let bufferSize = 128 * 1024
    private static let maxTokenChars = 4096

    private let rootURL: URL
    private let identityURL: URL
    private let indexURL: URL
    private let blobRootURL: URL
    private let stagingRootURL: URL
    private let maxItemBytes: Int64
    private let maxWorkspaceBytes: Int64
    private let maxGlobalBytes: Int64
    private let defaultTTL: TimeInterval
    private let maxTTL: TimeInterval
    private let now: () -> Date
    private let faultInjector: ((String, Int64) throws -> Void)?
    private let lock = NSLock()

    private var identity: StoreIdentity
    private var references: [ReferenceRecord]

    convenience init(options: ArtifactContentStoreOptions) throws {
        try self.init(
            rootURL: options.rootURL,
            workspaceRootForIsolation: options.workspaceRootForIsolation,
            maxItemBytes: options.maxItemBytes,
            maxWorkspaceBytes: options.maxWorkspaceBytes,
            maxGlobalBytes: options.maxGlobalBytes,
            defaultTTL: options.defaultTTL,
            maxTTL: options.maxTTL,
            now: options.now,
            faultInjector: { stage, size in
                if let error = options.faultInjector?(stage, size) {
                    throw error
                }
            }
        )
    }

    init(
        rootURL: URL? = nil,
        workspaceRootForIsolation: URL? = nil,
        maxItemBytes: Int64 = ArtifactContentStore.defaultMaxItemBytes,
        maxWorkspaceBytes: Int64 = ArtifactContentStore.defaultMaxWorkspaceBytes,
        maxGlobalBytes: Int64 = ArtifactContentStore.defaultMaxGlobalBytes,
        defaultTTL: TimeInterval = ArtifactContentStore.defaultTTL,
        maxTTL: TimeInterval = ArtifactContentStore.defaultMaxTTL,
        now: @escaping () -> Date = Date.init,
        faultInjector: ((String, Int64) throws -> Void)? = nil
    ) throws {
        guard maxItemBytes > 0,
              maxWorkspaceBytes >= maxItemBytes,
              maxGlobalBytes >= maxWorkspaceBytes else {
            throw ArtifactContentStoreError.invalid("Artifact quota configuration is invalid")
        }
        guard defaultTTL > 0, maxTTL > 0, defaultTTL <= maxTTL, maxTTL <= 30 * 24 * 60 * 60 else {
            throw ArtifactContentStoreError.invalid("Artifact TTL configuration is invalid")
        }

        let selectedRoot: URL
        if let rootURL {
            selectedRoot = rootURL.standardizedFileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
            selectedRoot = base.appendingPathComponent("FileMCP/artifacts-v1", isDirectory: true).standardizedFileURL
        }

        let isolationCandidate = selectedRoot.standardizedFileURL
        if let workspaceRootForIsolation {
            let workspace = workspaceRootForIsolation.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL
            if Self.isSameOrDescendant(isolationCandidate.path, root: workspace.path) {
                throw ArtifactContentStoreError.invalid("Artifact root must be outside the workspace/repository")
            }
        }

        try Self.hardenDirectory(selectedRoot)
        let canonicalRoot = selectedRoot.resolvingSymlinksInPath().standardizedFileURL

        if let workspaceRootForIsolation {
            let workspace = workspaceRootForIsolation.resolvingSymlinksInPath().standardizedFileURL
            if Self.isSameOrDescendant(canonicalRoot.path, root: workspace.path) {
                throw ArtifactContentStoreError.invalid("Artifact root must be outside the workspace/repository")
            }
        }

        self.rootURL = canonicalRoot
        self.identityURL = canonicalRoot.appendingPathComponent("identity-v1.json")
        self.indexURL = canonicalRoot.appendingPathComponent("index-v1.json")
        self.blobRootURL = canonicalRoot.appendingPathComponent("blobs", isDirectory: true)
        self.stagingRootURL = canonicalRoot.appendingPathComponent("staging", isDirectory: true)
        self.maxItemBytes = maxItemBytes
        self.maxWorkspaceBytes = maxWorkspaceBytes
        self.maxGlobalBytes = maxGlobalBytes
        self.defaultTTL = defaultTTL
        self.maxTTL = maxTTL
        self.now = now
        self.faultInjector = faultInjector

        try Self.hardenDirectory(self.blobRootURL)
        try Self.hardenDirectory(self.stagingRootURL)
        self.identity = try Self.loadOrCreateIdentity(at: self.identityURL)
        self.references = try Self.loadSnapshot(at: self.indexURL)

        _ = try withLock { try cleanupLocked() }
    }

    static func workspaceAuthorityID(_ workspacePath: String) -> String {
        let canonical = URL(fileURLWithPath: workspacePath).standardizedFileURL.resolvingSymlinksInPath().path
        return "sha256:" + SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func workspaceAuthorityID(_ workspaceURL: URL) -> String {
        workspaceAuthorityID(workspaceURL.path)
    }

    func initialize() throws {
        // Initialization is eager and transactional in init; this is an idempotent compatibility hook.
    }

    func put(
        data: Data,
        workspaceAuthorityID: String,
        contentClass: String,
        mediaType: String = "application/octet-stream",
        ttl: TimeInterval? = nil,
        leaseID: String? = nil,
        leaseTTL: TimeInterval? = nil
    ) throws -> ArtifactContentDescriptor {
        guard let input = InputStream(data: data) as InputStream? else {
            throw ArtifactContentStoreError.io("Could not create artifact input stream")
        }
        return try put(
            input: input,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClass: contentClass,
            mediaType: mediaType,
            ttl: ttl,
            leaseID: leaseID,
            leaseTTL: leaseTTL
        )
    }

    func put(
        input: InputStream,
        workspaceAuthorityID: String,
        contentClass: String,
        mediaType: String = "application/octet-stream",
        ttl: TimeInterval? = nil,
        leaseID: String? = nil,
        leaseTTL: TimeInterval? = nil
    ) throws -> ArtifactContentDescriptor {
        try Self.validateWorkspaceAuthority(workspaceAuthorityID)
        try Self.validateContentClass(contentClass)
        try Self.validateBoundString(mediaType, name: "mediaType", max: 512)
        if let leaseID { try Self.validateBoundString(leaseID, name: "leaseID", max: 512) }
        guard leaseID != nil || leaseTTL == nil else {
            throw ArtifactContentStoreError.invalid("Artifact lease TTL requires a lease id")
        }

        let effectiveTTL = ttl ?? defaultTTL
        guard effectiveTTL > 0, effectiveTTL <= maxTTL else {
            throw ArtifactContentStoreError.invalid("Artifact TTL must be positive and bounded")
        }
        if let leaseTTL {
            guard leaseTTL > 0, leaseTTL <= effectiveTTL else {
                throw ArtifactContentStoreError.invalid("Artifact lease TTL must be positive and no longer than the ContentRef TTL")
            }
        }

        return try withLock {
            _ = try cleanupLocked()

            let stageURL = stagingRootURL.appendingPathComponent("stage_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())")
            var stageExists = false
            var publishedNewBlob = false
            var publishedBlobURL: URL?
            defer {
                if stageExists { try? FileManager.default.removeItem(at: stageURL) }
            }

            let staged = try stageAndHash(input: input, stageURL: stageURL)
            stageExists = true

            let hash = String(staged.blobID.dropFirst("sha256:".count))
            let bucket = blobRootURL.appendingPathComponent(String(hash.prefix(2)), isDirectory: true)
            try Self.hardenDirectory(bucket)
            let blobURL = bucket.appendingPathComponent(hash)
            publishedBlobURL = blobURL
            let blobExists = FileManager.default.fileExists(atPath: blobURL.path)

            let globalBytes = computeGlobalBytes(references)
            let workspaceBytes = computeWorkspaceBytes(references, workspaceAuthorityID: workspaceAuthorityID)
            let nowMs = epochMs(now())
            let workspaceAlreadyReferencesBlob = references.contains {
                $0.workspaceAuthorityID == workspaceAuthorityID &&
                $0.blobID == staged.blobID &&
                $0.expiresEpochMs > nowMs
            }

            if !blobExists, globalBytes + staged.sizeBytes > maxGlobalBytes {
                throw ArtifactContentStoreError.quota("Artifact global quota exhausted")
            }
            if !workspaceAlreadyReferencesBlob, workspaceBytes + staged.sizeBytes > maxWorkspaceBytes {
                throw ArtifactContentStoreError.quota("Artifact workspace quota exhausted")
            }

            try faultInjector?("before-publish", staged.sizeBytes)

            if blobExists {
                try FileManager.default.removeItem(at: stageURL)
                stageExists = false
                try verifyBlobIntegrity(blobURL, expectedBlobID: staged.blobID, expectedSize: staged.sizeBytes)
            } else {
                try FileManager.default.moveItem(at: stageURL, to: blobURL)
                stageExists = false
                publishedNewBlob = true
                try Self.hardenFile(blobURL)
            }

            let created = now()
            let record = ReferenceRecord(
                referenceID: "ref_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
                blobID: staged.blobID,
                sizeBytes: staged.sizeBytes,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClass: contentClass,
                mediaType: mediaType,
                createdEpochMs: epochMs(created),
                expiresEpochMs: epochMs(created.addingTimeInterval(effectiveTTL)),
                leaseID: leaseID,
                leaseExpiresEpochMs: leaseTTL.map { epochMs(created.addingTimeInterval($0)) }
            )
            let contentRef = try encodeContentRef(record)
            var candidate = references
            candidate.append(record)

            do {
                try faultInjector?("before-index-commit", staged.sizeBytes)
                try persistSnapshot(candidate)
                references = candidate
            } catch {
                if publishedNewBlob,
                   let publishedBlobURL,
                   !references.contains(where: { $0.blobID == record.blobID }) {
                    try? FileManager.default.removeItem(at: publishedBlobURL)
                }
                throw error
            }

            return descriptor(record, contentRef: contentRef)
        }
    }

    func resolve(
        _ contentRef: String,
        workspaceAuthorityID: String,
        contentClassAllowed: (String) -> Bool
    ) throws -> ArtifactContentDescriptor {
        try resolve(
            contentRef: contentRef,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: contentClassAllowed
        )
    }

    func resolve(
        contentRef: String,
        workspaceAuthorityID: String,
        contentClassAllowed: (String) -> Bool
    ) throws -> ArtifactContentDescriptor {
        try Self.validateWorkspaceAuthority(workspaceAuthorityID)
        return try withLock {
            let record = try resolveRecordLocked(
                contentRef: contentRef,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClassAllowed: contentClassAllowed
            )
            return descriptor(record, contentRef: contentRef)
        }
    }

    func copy(
        _ contentRef: String,
        workspaceAuthorityID: String,
        contentClassAllowed: (String) -> Bool,
        to output: OutputStream
    ) throws {
        try copy(
            contentRef: contentRef,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: contentClassAllowed,
            to: output
        )
    }

    func copy(
        contentRef: String,
        workspaceAuthorityID: String,
        contentClassAllowed: (String) -> Bool,
        to output: OutputStream
    ) throws {
        try Self.validateWorkspaceAuthority(workspaceAuthorityID)
        try withLock {
            let record = try resolveRecordLocked(
                contentRef: contentRef,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClassAllowed: contentClassAllowed
            )
            let blobURL = pathForBlob(record.blobID)
            guard let input = InputStream(url: blobURL) else {
                throw ArtifactContentStoreError.unavailable("ContentRef blob unavailable")
            }
            input.open()
            output.open()
            defer {
                input.close()
                output.close()
            }

            var buffer = [UInt8](repeating: 0, count: Self.bufferSize)
            while true {
                let read = input.read(&buffer, maxLength: buffer.count)
                if read < 0 {
                    throw ArtifactContentStoreError.io("Artifact stream read failed: \(input.streamError?.localizedDescription ?? "unknown error")")
                }
                if read == 0 { break }
                var offset = 0
                while offset < read {
                    let written = buffer.withUnsafeBufferPointer { pointer in
                        output.write(pointer.baseAddress!.advanced(by: offset), maxLength: read - offset)
                    }
                    if written <= 0 {
                        throw ArtifactContentStoreError.io("Artifact stream write failed: \(output.streamError?.localizedDescription ?? "unknown error")")
                    }
                    offset += written
                }
            }
        }
    }

    @discardableResult
    func delete(
        _ contentRef: String,
        workspaceAuthorityID: String,
        contentClassAllowed: (String) -> Bool
    ) throws -> Bool {
        try delete(
            contentRef: contentRef,
            workspaceAuthorityID: workspaceAuthorityID,
            contentClassAllowed: contentClassAllowed
        )
    }

    @discardableResult
    func delete(
        contentRef: String,
        workspaceAuthorityID: String,
        contentClassAllowed: (String) -> Bool
    ) throws -> Bool {
        try Self.validateWorkspaceAuthority(workspaceAuthorityID)
        return try withLock {
            let record = try resolveRecordLocked(
                contentRef: contentRef,
                workspaceAuthorityID: workspaceAuthorityID,
                contentClassAllowed: contentClassAllowed
            )
            let candidate = references.filter { $0.referenceID != record.referenceID }
            try persistSnapshot(candidate)
            references = candidate

            if !references.contains(where: { $0.blobID == record.blobID }) {
                try? FileManager.default.removeItem(at: pathForBlob(record.blobID))
            }
            return true
        }
    }

    func collectGarbage() throws -> ArtifactGCResult {
        try withLock { try cleanupLocked() }
    }

    func usage(workspaceAuthorityID: String) throws -> ArtifactStoreUsage {
        try Self.validateWorkspaceAuthority(workspaceAuthorityID)
        return withLock {
            let nowMs = epochMs(now())
            let live = references.filter { $0.expiresEpochMs > nowMs }
            return ArtifactStoreUsage(
                referenceCount: live.count,
                blobCount: Set(live.map(\.blobID)).count,
                globalBytes: computeGlobalBytes(live),
                workspaceBytes: computeWorkspaceBytes(live, workspaceAuthorityID: workspaceAuthorityID)
            )
        }
    }

    var rootURLForTest: URL { rootURL }
    var indexURLForTest: URL { indexURL }
    var identityURLForTest: URL { identityURL }
    func blobURLForTest(_ blobID: String) throws -> URL { try pathForBlobValidated(blobID) }

    func hasCurrentUserOnlyPermissionsForTest() -> Bool {
        let manager = FileManager.default
        guard let rootPermissions = (try? manager.attributesOfItem(atPath: rootURL.path)[.posixPermissions]) as? NSNumber,
              rootPermissions.intValue & 0o777 == 0o700 else {
            return false
        }
        for url in [identityURL, indexURL] where manager.fileExists(atPath: url.path) {
            guard let permissions = (try? manager.attributesOfItem(atPath: url.path)[.posixPermissions]) as? NSNumber,
                  permissions.intValue & 0o777 == 0o600 else {
                return false
            }
        }
        return true
    }

    private func resolveRecordLocked(
        contentRef: String,
        workspaceAuthorityID: String,
        contentClassAllowed: (String) -> Bool
    ) throws -> ReferenceRecord {
        let payload = try decodeContentRef(contentRef)
        guard payload.installationID == identity.installationID else {
            throw ArtifactContentStoreError.invalid("ContentRef installation mismatch")
        }
        guard payload.workspaceAuthorityID == workspaceAuthorityID else {
            throw ArtifactContentStoreError.invalid("ContentRef workspace mismatch")
        }
        guard ArtifactContentClasses.isKnown(payload.contentClass), contentClassAllowed(payload.contentClass) else {
            throw ArtifactContentStoreError.invalid("ContentRef content class denied by current policy")
        }

        let nowMs = epochMs(now())
        guard payload.expiresEpochMs > nowMs else {
            throw ArtifactContentStoreError.unavailable("ContentRef expired")
        }
        if let leaseExpiry = payload.leaseExpiresEpochMs, leaseExpiry <= nowMs {
            throw ArtifactContentStoreError.unavailable("ContentRef lease expired")
        }

        guard let record = references.first(where: { $0.referenceID == payload.referenceID }) else {
            throw ArtifactContentStoreError.unavailable("ContentRef unavailable")
        }
        guard record.blobID == payload.blobID,
              record.workspaceAuthorityID == payload.workspaceAuthorityID,
              record.contentClass == payload.contentClass,
              record.expiresEpochMs == payload.expiresEpochMs,
              record.leaseID == payload.leaseID,
              record.leaseExpiresEpochMs == payload.leaseExpiresEpochMs else {
            throw ArtifactContentStoreError.integrity("ContentRef metadata mismatch")
        }

        let blobURL = try pathForBlobValidated(record.blobID)
        guard FileManager.default.fileExists(atPath: blobURL.path) else {
            throw ArtifactContentStoreError.unavailable("ContentRef blob unavailable")
        }
        try verifyBlobIntegrity(blobURL, expectedBlobID: record.blobID, expectedSize: record.sizeBytes)
        return record
    }

    private func stageAndHash(input: InputStream, stageURL: URL) throws -> (blobID: String, sizeBytes: Int64) {
        guard FileManager.default.createFile(
            atPath: stageURL.path,
            contents: nil,
            attributes: [.posixPermissions: NSNumber(value: 0o600)]
        ) else {
            throw ArtifactContentStoreError.io("Could not create artifact staging file")
        }

        input.open()
        defer { input.close() }
        let handle: FileHandle
        do {
            handle = try FileHandle(forWritingTo: stageURL)
        } catch {
            try? FileManager.default.removeItem(at: stageURL)
            throw ArtifactContentStoreError.io("Could not open artifact staging file: \(error.localizedDescription)")
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        var total: Int64 = 0
        var buffer = [UInt8](repeating: 0, count: Self.bufferSize)

        do {
            while true {
                let read = input.read(&buffer, maxLength: buffer.count)
                if read < 0 {
                    throw ArtifactContentStoreError.io("Artifact stream read failed: \(input.streamError?.localizedDescription ?? "unknown error")")
                }
                if read == 0 { break }
                total += Int64(read)
                if total > maxItemBytes {
                    throw ArtifactContentStoreError.quota("Artifact per-item quota exhausted")
                }
                let data = Data(buffer[0..<read])
                hasher.update(data: data)
                try handle.write(contentsOf: data)
            }
            try handle.synchronize()
        } catch {
            try? FileManager.default.removeItem(at: stageURL)
            throw error
        }

        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return ("sha256:" + digest, total)
    }

    private func verifyBlobIntegrity(_ url: URL, expectedBlobID: String, expectedSize: Int64) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.int64Value == expectedSize else {
            throw ArtifactContentStoreError.integrity("Artifact blob is corrupt: size mismatch")
        }
        let actual = try Self.sha256File(url)
        guard actual == expectedBlobID else {
            throw ArtifactContentStoreError.integrity("Artifact blob is corrupt: digest mismatch")
        }
    }

    private func cleanupLocked() throws -> ArtifactGCResult {
        let nowMs = epochMs(now())
        let live = references.filter { $0.expiresEpochMs > nowMs }
        let expiredRemoved = references.count - live.count
        if expiredRemoved > 0 {
            try persistSnapshot(live)
            references = live
        }

        let referenced = Set(references.map { String($0.blobID.dropFirst("sha256:".count)) })
        var orphanRemoved = 0
        if let enumerator = FileManager.default.enumerator(
            at: blobRootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if values?.isRegularFile == true, !referenced.contains(fileURL.lastPathComponent) {
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                        orphanRemoved += 1
                    } catch { }
                }
            }
        }

        var stagingRemoved = 0
        if let staging = try? FileManager.default.contentsOfDirectory(
            at: stagingRootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for file in staging {
                do {
                    try FileManager.default.removeItem(at: file)
                    stagingRemoved += 1
                } catch { }
            }
        }

        return ArtifactGCResult(
            expiredReferencesRemoved: expiredRemoved,
            orphanBlobsRemoved: orphanRemoved,
            stagingFilesRemoved: stagingRemoved
        )
    }

    private func persistSnapshot(_ candidate: [ReferenceRecord]) throws {
        let snapshot = StoreSnapshot(schemaVersion: Self.schemaVersion, references: candidate)
        let data: Data
        do {
            data = try JSONEncoder().encode(snapshot)
        } catch {
            throw ArtifactContentStoreError.io("Could not encode artifact metadata index: \(error.localizedDescription)")
        }
        try Self.writeAtomic(data, to: indexURL, permissions: 0o600)
    }

    private func encodeContentRef(_ record: ReferenceRecord) throws -> String {
        let payloadText = [
            "1",
            identity.installationID,
            record.workspaceAuthorityID,
            record.blobID,
            record.contentClass,
            String(record.expiresEpochMs),
            record.referenceID,
            record.leaseID ?? "-",
            String(record.leaseExpiresEpochMs ?? 0),
        ].joined(separator: "|")
        let payload = Data(payloadText.utf8)
        let key = try identity.keyData()
        let signature = Data(HMAC<SHA256>.authenticationCode(for: payload, using: SymmetricKey(data: key)))
        return "cr1." + Self.base64URL(payload) + "." + Self.base64URL(signature)
    }

    private func decodeContentRef(_ contentRef: String) throws -> ContentRefPayload {
        guard !contentRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              contentRef.count <= Self.maxTokenChars else {
            throw ArtifactContentStoreError.invalid("Malformed ContentRef")
        }

        let parts = contentRef.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, parts[0] == "cr1",
              let payload = Self.fromBase64URL(parts[1]),
              let signature = Self.fromBase64URL(parts[2]),
              !payload.isEmpty, payload.count <= 3072, signature.count == 32 else {
            throw ArtifactContentStoreError.invalid("Malformed ContentRef")
        }

        let keyData = try identity.keyData()
        guard HMAC<SHA256>.isValidAuthenticationCode(
            signature,
            authenticating: payload,
            using: SymmetricKey(data: keyData)
        ) else {
            throw ArtifactContentStoreError.invalid("ContentRef authentication failed")
        }

        guard let text = String(data: payload, encoding: .utf8) else {
            throw ArtifactContentStoreError.invalid("Malformed ContentRef payload")
        }
        let fields = text.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 9, fields[0] == "1",
              let expiry = Int64(fields[5]),
              let leaseExpiryRaw = Int64(fields[8]) else {
            throw ArtifactContentStoreError.invalid("Malformed ContentRef payload")
        }

        try Self.validateBoundString(fields[1], name: "installationID", max: 128)
        try Self.validateWorkspaceAuthority(fields[2])
        try Self.validateBlobID(fields[3])
        try Self.validateContentClass(fields[4])
        try Self.validateBoundString(fields[6], name: "referenceID", max: 128)

        let leaseID = fields[7] == "-" ? nil : fields[7]
        if let leaseID { try Self.validateBoundString(leaseID, name: "leaseID", max: 512) }
        let leaseExpiry: Int64? = leaseExpiryRaw == 0 ? nil : leaseExpiryRaw
        guard (leaseID == nil) == (leaseExpiry == nil) else {
            throw ArtifactContentStoreError.invalid("Malformed ContentRef lease payload")
        }

        return ContentRefPayload(
            installationID: fields[1],
            workspaceAuthorityID: fields[2],
            blobID: fields[3],
            contentClass: fields[4],
            expiresEpochMs: expiry,
            referenceID: fields[6],
            leaseID: leaseID,
            leaseExpiresEpochMs: leaseExpiry
        )
    }

    private func pathForBlob(_ blobID: String) -> URL {
        let hash = String(blobID.dropFirst("sha256:".count))
        return blobRootURL
            .appendingPathComponent(String(hash.prefix(2)), isDirectory: true)
            .appendingPathComponent(hash)
    }

    private func pathForBlobValidated(_ blobID: String) throws -> URL {
        try Self.validateBlobID(blobID)
        return pathForBlob(blobID)
    }

    private func computeGlobalBytes(_ records: [ReferenceRecord]) -> Int64 {
        Dictionary(grouping: records, by: \.blobID).values.reduce(0) { partial, group in
            partial + (group.first?.sizeBytes ?? 0)
        }
    }

    private func computeWorkspaceBytes(_ records: [ReferenceRecord], workspaceAuthorityID: String) -> Int64 {
        let scoped = records.filter { $0.workspaceAuthorityID == workspaceAuthorityID }
        return Dictionary(grouping: scoped, by: \.blobID).values.reduce(0) { partial, group in
            partial + (group.first?.sizeBytes ?? 0)
        }
    }

    private func descriptor(_ record: ReferenceRecord, contentRef: String) -> ArtifactContentDescriptor {
        ArtifactContentDescriptor(
            contentRef: contentRef,
            referenceID: record.referenceID,
            blobID: record.blobID,
            sizeBytes: record.sizeBytes,
            contentClass: record.contentClass,
            mediaType: record.mediaType,
            createdEpochMs: record.createdEpochMs,
            expiresEpochMs: record.expiresEpochMs,
            leaseID: record.leaseID,
            leaseExpiresEpochMs: record.leaseExpiresEpochMs
        )
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func epochMs(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

    private static func loadOrCreateIdentity(at url: URL) throws -> StoreIdentity {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let identity = try JSONDecoder().decode(StoreIdentity.self, from: Data(contentsOf: url))
                try validateIdentity(identity)
                return identity
            } catch let error as ArtifactContentStoreError {
                throw error
            } catch {
                throw ArtifactContentStoreError.integrity("Artifact store identity is corrupt: \(error.localizedDescription)")
            }
        }

        var random = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, random.count, &random)
        guard status == errSecSuccess else {
            throw ArtifactContentStoreError.io("Could not generate artifact authentication key (OSStatus \(status))")
        }
        let created = StoreIdentity(
            schemaVersion: schemaVersion,
            installationID: "inst_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            authenticationKey: Data(random).base64EncodedString()
        )
        let data = try JSONEncoder().encode(created)
        try writeAtomic(data, to: url, permissions: 0o600)
        return created
    }

    private static func loadSnapshot(at url: URL) throws -> [ReferenceRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let snapshot = try JSONDecoder().decode(StoreSnapshot.self, from: Data(contentsOf: url))
            guard snapshot.schemaVersion == schemaVersion else {
                throw ArtifactContentStoreError.invalid("Unsupported artifact metadata schema version")
            }
            for record in snapshot.references { try validateRecord(record) }
            return snapshot.references
        } catch let error as ArtifactContentStoreError {
            throw error
        } catch {
            throw ArtifactContentStoreError.integrity("Artifact metadata index is corrupt: \(error.localizedDescription)")
        }
    }

    private static func validateIdentity(_ identity: StoreIdentity) throws {
        guard identity.schemaVersion == schemaVersion else {
            throw ArtifactContentStoreError.invalid("Unsupported artifact identity schema version")
        }
        try validateBoundString(identity.installationID, name: "installationID", max: 128)
        _ = try identity.keyData()
    }

    private static func validateRecord(_ record: ReferenceRecord) throws {
        try validateBoundString(record.referenceID, name: "referenceID", max: 128)
        try validateBlobID(record.blobID)
        try validateWorkspaceAuthority(record.workspaceAuthorityID)
        try validateContentClass(record.contentClass)
        try validateBoundString(record.mediaType, name: "mediaType", max: 512)
        guard record.sizeBytes >= 0,
              record.createdEpochMs >= 0,
              record.expiresEpochMs > record.createdEpochMs else {
            throw ArtifactContentStoreError.integrity("Artifact metadata record is invalid")
        }
        if let leaseID = record.leaseID {
            try validateBoundString(leaseID, name: "leaseID", max: 512)
        }
        guard (record.leaseID == nil) == (record.leaseExpiresEpochMs == nil) else {
            throw ArtifactContentStoreError.integrity("Artifact lease metadata is invalid")
        }
        if let leaseExpiry = record.leaseExpiresEpochMs {
            guard leaseExpiry > record.createdEpochMs, leaseExpiry <= record.expiresEpochMs else {
                throw ArtifactContentStoreError.integrity("Artifact lease expiry is invalid")
            }
        }
    }

    private static func validateWorkspaceAuthority(_ value: String) throws {
        try validateBoundString(value, name: "workspaceAuthorityID", max: 256)
        guard value.hasPrefix("sha256:"), value.count == "sha256:".count + 64 else {
            throw ArtifactContentStoreError.invalid("Malformed workspace authority id")
        }
        let suffix = value.dropFirst("sha256:".count)
        guard suffix.allSatisfy({ $0.isHexDigit }) else {
            throw ArtifactContentStoreError.invalid("Malformed workspace authority id")
        }
    }

    private static func validateBlobID(_ value: String) throws {
        guard value.hasPrefix("sha256:"), value.count == "sha256:".count + 64 else {
            throw ArtifactContentStoreError.invalid("Malformed artifact blob id")
        }
        let suffix = value.dropFirst("sha256:".count)
        guard suffix.allSatisfy({ $0.isHexDigit }) else {
            throw ArtifactContentStoreError.invalid("Malformed artifact blob id")
        }
    }

    private static func validateContentClass(_ value: String) throws {
        guard ArtifactContentClasses.isKnown(value) else {
            throw ArtifactContentStoreError.invalid("Unsupported artifact content class")
        }
    }

    private static func validateBoundString(_ value: String, name: String, max: Int) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.count <= max,
              !value.contains("|") else {
            throw ArtifactContentStoreError.invalid("\(name) must be a non-empty bounded string without reserved separators")
        }
    }

    private static func hardenDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        do {
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o700)],
                ofItemAtPath: url.path
            )
        } catch {
            throw ArtifactContentStoreError.io("Could not enforce current-user-only artifact directory permissions: \(error.localizedDescription)")
        }
    }

    private static func hardenFile(_ url: URL) throws {
        do {
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o600)],
                ofItemAtPath: url.path
            )
        } catch {
            throw ArtifactContentStoreError.io("Could not enforce current-user-only artifact file permissions: \(error.localizedDescription)")
        }
    }

    private static func writeAtomic(_ data: Data, to url: URL, permissions: Int) throws {
        let directory = url.deletingLastPathComponent()
        try hardenDirectory(directory)
        do {
            try data.write(to: url, options: [.atomic])
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: permissions)],
                ofItemAtPath: url.path
            )
        } catch {
            throw ArtifactContentStoreError.io("Could not atomically persist artifact metadata: \(error.localizedDescription)")
        }
    }

    private static func isSameOrDescendant(_ candidate: String, root: String) -> Bool {
        candidate == root || candidate.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    private static func sha256File(_ url: URL) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw ArtifactContentStoreError.unavailable("ContentRef blob unavailable")
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: bufferSize) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return "sha256:" + hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func fromBase64URL(_ value: String) -> Data? {
        guard !value.isEmpty, value.count <= maxTokenChars else { return nil }
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let decoded = Data(base64Encoded: base64), base64URL(decoded) == value else { return nil }
        return decoded
    }

    private struct StoreIdentity: Codable {
        let schemaVersion: Int
        let installationID: String
        let authenticationKey: String

        func keyData() throws -> Data {
            guard let data = Data(base64Encoded: authenticationKey), data.count == 32 else {
                throw ArtifactContentStoreError.integrity("Artifact authentication key is malformed")
            }
            return data
        }
    }

    private struct StoreSnapshot: Codable {
        let schemaVersion: Int
        let references: [ReferenceRecord]
    }

    private struct ReferenceRecord: Codable {
        let referenceID: String
        let blobID: String
        let sizeBytes: Int64
        let workspaceAuthorityID: String
        let contentClass: String
        let mediaType: String
        let createdEpochMs: Int64
        let expiresEpochMs: Int64
        let leaseID: String?
        let leaseExpiresEpochMs: Int64?
    }

    private struct ContentRefPayload {
        let installationID: String
        let workspaceAuthorityID: String
        let blobID: String
        let contentClass: String
        let expiresEpochMs: Int64
        let referenceID: String
        let leaseID: String?
        let leaseExpiresEpochMs: Int64?
    }
}
