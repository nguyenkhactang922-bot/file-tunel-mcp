import Foundation

enum BatchFileServiceError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case let .invalid(message): return message
        }
    }
}

final class BatchFileService {
    static let maxBatchEntries = 1024
    static let defaultReadBytes = 64 * 1024
    static let maxPerEntryBytes = 50 * 1024 * 1024

    private let resolver: SafePathResolver
    private let versions: FileVersionService
    private let artifactFactory: () throws -> ArtifactContentStore
    private let workspaceAuthorityID: String
    private let stageForTests: ((String, Int) -> Void)?
    private var artifactStore: ArtifactContentStore?

    init(
        resolver: SafePathResolver,
        versions: FileVersionService,
        artifactFactory: (() throws -> ArtifactContentStore)? = nil,
        stageForTests: ((String, Int) -> Void)? = nil
    ) {
        self.resolver = resolver
        self.versions = versions
        self.workspaceAuthorityID = ArtifactContentStore.workspaceAuthorityID(resolver.root)
        self.stageForTests = stageForTests
        self.artifactFactory = artifactFactory ?? {
            var options = ArtifactContentStoreOptions()
            options.workspaceRootForIsolation = resolver.root
            return try ArtifactContentStore(options: options)
        }
    }

    func stat(paths: [Any], context: ToolExecutionContext?) throws -> [String: Any] {
        let effective = try context ?? ToolExecutionContext(meta: nil)
        guard !paths.isEmpty else {
            throw BatchFileServiceError.invalid("paths must contain at least one entry")
        }
        guard paths.count <= Self.maxBatchEntries else {
            throw BatchFileServiceError.invalid("paths may contain at most \(Self.maxBatchEntries) entries")
        }

        var entries: [[String: Any]] = []
        var completed = 0

        for (index, raw) in paths.enumerated() {
            guard effective.tryVisitEntry() else { break }
            let requested = try requiredPath(raw, collectionName: "paths", index: index)

            let item: [String: Any]
            do {
                let target = try resolver.resolve(requested)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
                        item = [
                            "path": requested,
                            "state": "ok",
                            "entry_type": "directory",
                            "size_bytes": 0,
                            "modified_utc": iso8601(attributes[.modificationDate] as? Date),
                        ]
                    } else {
                        let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
                        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                        guard effective.tryScanFile(bytes: size) else {
                            let budget = errorEntry(
                                path: requested,
                                code: "budget_exhausted",
                                message: "Aggregate batch budget exhausted while versioning file")
                            if effective.tryOutputItem() { entries.append(budget) }
                            break
                        }

                        let versioned = try versions.readVersioned(relativePath: requested, maxBytes: Self.maxPerEntryBytes)
                        item = [
                            "path": requested,
                            "state": "ok",
                            "entry_type": "file",
                            "size_bytes": versioned.sizeBytes,
                            "modified_utc": iso8601(attributes[.modificationDate] as? Date),
                            "version": versioned.versionToken,
                            "version_strength": "content",
                        ]
                    }
                } else {
                    item = errorEntry(path: requested, code: "not_found", message: "Path does not exist")
                }
            } catch {
                item = errorEntry(path: requested, code: errorCode(error), message: publicError(error))
            }

            guard effective.tryOutputItem() else { break }
            entries.append(item)
            completed += 1
            stageForTests?("after_entry", index)
        }

        return summary(
            operation: "batch_stat",
            requested: paths.count,
            completed: completed,
            entries: entries,
            context: effective)
    }

    func read(requests: [Any], context: ToolExecutionContext?) throws -> [String: Any] {
        let effective = try context ?? ToolExecutionContext(meta: nil)
        guard !requests.isEmpty else {
            throw BatchFileServiceError.invalid("requests must contain at least one entry")
        }
        guard requests.count <= Self.maxBatchEntries else {
            throw BatchFileServiceError.invalid("requests may contain at most \(Self.maxBatchEntries) entries")
        }

        var entries: [[String: Any]] = []
        var completed = 0

        for (index, raw) in requests.enumerated() {
            guard effective.tryVisitEntry() else { break }
            let request = try requiredRequest(raw, index: index)
            let path = try requiredRequestString(request, key: "relative_path", index: index)
            let maxBytes = try optionalPositiveInt(
                request,
                key: "max_bytes",
                fallback: Self.defaultReadBytes,
                maximum: Self.maxPerEntryBytes)
            let allowContentRef = try optionalBool(request, key: "allow_content_ref", fallback: false)

            let item: [String: Any]
            do {
                let target = try resolver.resolve(path)
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory) else {
                    item = errorEntry(path: path, code: "not_found", message: "Path does not exist")
                    if effective.tryOutputItem() {
                        entries.append(item)
                        completed += 1
                    }
                    continue
                }
                guard !isDirectory.boolValue else {
                    item = errorEntry(path: path, code: "not_file", message: "Path is not a file")
                    if effective.tryOutputItem() {
                        entries.append(item)
                        completed += 1
                    }
                    continue
                }

                let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
                let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                guard effective.tryScanFile(bytes: size) else {
                    let budget = errorEntry(
                        path: path,
                        code: "budget_exhausted",
                        message: "Aggregate batch budget exhausted while reading file")
                    if effective.tryOutputItem() { entries.append(budget) }
                    break
                }
                guard effective.tryContinue() else { break }

                let versioned = try versions.readVersioned(relativePath: path, maxBytes: Self.maxPerEntryBytes)
                stageForTests?("after_versioned", index)
                if versioned.sizeBytes <= Int64(maxBytes) {
                    item = [
                        "path": path,
                        "state": "ok",
                        "delivery": "inline",
                        "content": String(decoding: versioned.data, as: UTF8.self),
                        "size_bytes": versioned.sizeBytes,
                        "version": versioned.versionToken,
                        "version_strength": "content",
                    ]
                } else if allowContentRef {
                    let input = InputStream(data: versioned.data)
                    let artifact = try artifacts().put(
                        input: input,
                        workspaceAuthorityID: workspaceAuthorityID,
                        contentClass: ArtifactContentClasses.toolOutput,
                        mediaType: "application/octet-stream")
                    item = [
                        "path": path,
                        "state": "ok",
                        "delivery": "content_ref",
                        "content_ref": artifact.contentRef,
                        "blob_id": artifact.blobID,
                        "expires_epoch_ms": artifact.expiresEpochMs,
                        "size_bytes": versioned.sizeBytes,
                        "version": versioned.versionToken,
                        "version_strength": "content",
                    ]
                } else {
                    item = [
                        "path": path,
                        "state": "too_large",
                        "delivery": "none",
                        "size_bytes": versioned.sizeBytes,
                        "max_bytes": maxBytes,
                        "version": versioned.versionToken,
                        "version_strength": "content",
                    ]
                }
            } catch {
                item = errorEntry(path: path, code: errorCode(error), message: publicError(error))
            }

            guard effective.tryOutputItem() else { break }
            entries.append(item)
            completed += 1
            stageForTests?("after_entry", index)
        }

        return summary(
            operation: "batch_read",
            requested: requests.count,
            completed: completed,
            entries: entries,
            context: effective)
    }

    private func artifacts() throws -> ArtifactContentStore {
        if let artifactStore { return artifactStore }
        let created = try artifactFactory()
        artifactStore = created
        return created
    }

    private func summary(
        operation: String,
        requested: Int,
        completed: Int,
        entries: [[String: Any]],
        context: ToolExecutionContext
    ) -> [String: Any] {
        let partial = completed < requested || context.truncated
        return [
            "operation": operation,
            "requested_count": requested,
            "completed_count": completed,
            "partial": partial,
            "cancelled": context.truncationReason == "cancelled",
            "truncated": context.truncated,
            "truncation_reason": context.truncationReason,
            "entries": entries,
        ]
    }

    private func requiredPath(_ raw: Any, collectionName: String, index: Int) throws -> String {
        guard let path = raw as? String, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BatchFileServiceError.invalid("\(collectionName)[\(index)] must be a non-empty string path")
        }
        return path
    }

    private func requiredRequest(_ raw: Any, index: Int) throws -> [String: Any] {
        guard let request = raw as? [String: Any] else {
            throw BatchFileServiceError.invalid("requests[\(index)] must be an object")
        }
        let allowed: Set<String> = ["relative_path", "max_bytes", "allow_content_ref"]
        for key in request.keys where !allowed.contains(key) {
            throw BatchFileServiceError.invalid("requests[\(index)] contains unknown field: \(key)")
        }
        return request
    }

    private func requiredRequestString(_ request: [String: Any], key: String, index: Int) throws -> String {
        guard let value = request[key] as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BatchFileServiceError.invalid("requests[\(index)].\(key) must be a non-empty string")
        }
        return value
    }

    private func optionalPositiveInt(
        _ request: [String: Any],
        key: String,
        fallback: Int,
        maximum: Int
    ) throws -> Int {
        guard let raw = request[key] else { return fallback }
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            throw BatchFileServiceError.invalid("\(key) must be an integer between 1 and \(maximum)")
        }
        let value = number.intValue
        guard value > 0, value <= maximum, number.doubleValue == Double(value) else {
            throw BatchFileServiceError.invalid("\(key) must be an integer between 1 and \(maximum)")
        }
        return value
    }

    private func optionalBool(_ request: [String: Any], key: String, fallback: Bool) throws -> Bool {
        guard let raw = request[key] else { return fallback }
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw BatchFileServiceError.invalid("\(key) must be a boolean")
        }
        return number.boolValue
    }

    private func errorEntry(path: String, code: String, message: String) -> [String: Any] {
        [
            "path": path,
            "state": "error",
            "error_code": code,
            "error": message,
        ]
    }

    private func errorCode(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("outside the shared directory") { return "path_outside_root" }
        if message.localizedCaseInsensitiveContains("no such file") ||
            message.localizedCaseInsensitiveContains("does not exist") { return "not_found" }
        if message.localizedCaseInsensitiveContains("larger than") ||
            message.localizedCaseInsensitiveContains("too large") { return "too_large" }
        if message.localizedCaseInsensitiveContains("changed") ||
            message.localizedCaseInsensitiveContains("replaced") { return "file_changed" }
        if message.localizedCaseInsensitiveContains("quota") { return "artifact_quota" }
        if message.localizedCaseInsensitiveContains("contentref") { return "artifact_unavailable" }
        return "io_error"
    }

    private func publicError(_ error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "Batch entry failed" : message
    }

    private func iso8601(_ date: Date?) -> String {
        guard let date else { return "" }
        return ISO8601DateFormatter().string(from: date)
    }
}
