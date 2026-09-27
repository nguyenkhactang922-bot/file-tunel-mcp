import Foundation
import CryptoKit

struct EvidenceRequestSpec {
    static let metadataKey = "io.filemcp/evidence"
    static let allowedCriteria: Set<String> = ["tool.success", "process.exit_zero"]

    let criterionID: String
    let repoPath: String?
    let relevantPaths: [String]
    let required: Bool

    static func parse(meta: [String: Any]?, toolName: String) throws -> EvidenceRequestSpec? {
        guard let raw = meta?[metadataKey] else { return nil }
        guard let evidence = raw as? [String: Any] else {
            throw MCPServerError.invalidArguments("\(metadataKey) must be an object")
        }
        let allowed: Set<String> = ["criterionId", "repoPath", "relevantPaths", "required"]
        for key in evidence.keys where !allowed.contains(key) {
            throw MCPServerError.invalidArguments("Unknown evidence metadata field: \(key)")
        }
        guard let criterion = evidence["criterionId"] as? String,
              !criterion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              allowedCriteria.contains(criterion) else {
            throw MCPServerError.invalidArguments("Evidence criterionId must be one of the supported server-owned criteria")
        }
        if criterion == "process.exit_zero", toolName != "exec_process" {
            throw MCPServerError.invalidArguments("process.exit_zero evidence is only supported for exec_process")
        }
        var repoPath: String?
        if let rawRepo = evidence["repoPath"] {
            guard let value = rawRepo as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.count <= 4096 else {
                throw MCPServerError.invalidArguments("Evidence repoPath must be a non-empty bounded string")
            }
            repoPath = value
        }
        var relevantPaths: [String] = []
        if let rawPaths = evidence["relevantPaths"] {
            guard let values = rawPaths as? [Any], values.count <= 4096 else {
                throw MCPServerError.invalidArguments("Evidence relevantPaths supports at most 4096 paths")
            }
            relevantPaths = try values.map { raw in
                guard let value = raw as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.count <= 4096 else {
                    throw MCPServerError.invalidArguments("Evidence relevantPaths entries must be non-empty bounded strings")
                }
                return value
            }
            if repoPath == nil, !relevantPaths.isEmpty {
                throw MCPServerError.invalidArguments("Evidence relevantPaths requires repoPath")
            }
        }
        let required: Bool
        if let rawRequired = evidence["required"] {
            guard let value = rawRequired as? Bool else {
                throw MCPServerError.invalidArguments("Evidence required must be a boolean")
            }
            required = value
        } else {
            required = false
        }
        return EvidenceRequestSpec(criterionID: criterion, repoPath: repoPath, relevantPaths: relevantPaths, required: required)
    }
}

struct EvidenceEvaluation {
    let operationState: String
    let verificationState: String
    let exitCode: Int?
    let timedOut: Bool
    let cancelled: Bool
    let truncated: Bool
}

enum EvidenceEvaluator {
    static func evaluate(toolName: String, criterionID: String?, isError: Bool, structuredContent: [String: Any]?, context: ToolExecutionContext?) -> EvidenceEvaluation {
        let exitCode = integer(structuredContent?["exit_code"])
        let timedOut = bool(structuredContent?["timed_out"])
        let cancelled = bool(structuredContent?["cancelled"]) || (context?.cancellationRequested ?? false)
        let truncated = (context?.truncated ?? false) || bool(structuredContent?["truncated"]) || bool(structuredContent?["stdout_truncated"]) || bool(structuredContent?["stderr_truncated"])
        let operationState = timedOut ? "timed_out" : (cancelled ? "cancelled" : (isError ? "failed" : "succeeded"))
        let verification: String
        switch criterionID {
        case nil: verification = "not-run"
        case "tool.success": verification = isError ? "failed" : "passed"
        case "process.exit_zero" where toolName == "exec_process" && (timedOut || cancelled): verification = "unknown"
        case "process.exit_zero" where toolName == "exec_process" && exitCode != nil && exitCode != 0: verification = "failed"
        case "process.exit_zero" where toolName == "exec_process" && exitCode != nil && !isError: verification = "passed"
        default: verification = "unknown"
        }
        return EvidenceEvaluation(operationState: operationState, verificationState: verification, exitCode: exitCode, timedOut: timedOut, cancelled: cancelled, truncated: truncated)
    }

    private static func bool(_ value: Any?) -> Bool { value as? Bool ?? false }
    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, !(value is Bool), number.doubleValue == Double(number.intValue) else { return nil }
        return number.intValue
    }
}

struct EvidenceRecord: Codable {
    var evidenceID: String
    var operationID: String
    var workspaceFingerprint: String
    var toolName: String
    var criterionID: String
    var startedEpochMs: Int64
    var endedEpochMs: Int64?
    var operationState: String
    var verificationState: String
    var backendID: String
    var sourceStateJSON: String?
    var sourceStateID: String?
    var projectContextDigest: String?
    var policyGeneration: UInt64
    var policyHash: String
    var catalogHash: String
    var catalogVersion: String
    var exitCode: Int?
    var timedOut: Bool
    var cancelled: Bool
    var truncated: Bool
}

private struct EvidenceSnapshot: Codable {
    var schemaVersion: Int
    var records: [EvidenceRecord]
}

final class EvidenceStore {
    static let schemaVersion = 1
    static let maxSourceStateJSONBytes = 256 * 1024
    static let defaultRetention: TimeInterval = 30 * 24 * 60 * 60
    static let defaultMaxRecords = 10_000
    static let defaultMaxStoreBytes = 32 * 1024 * 1024

    private let fileURL: URL
    private let retention: TimeInterval
    private let maxRecords: Int
    private let maxStoreBytes: Int
    private let now: () -> Date
    private let lock = NSLock()
    private var records: [EvidenceRecord] = []
    private var unavailableReason: String?

    init(fileURL: URL? = nil, retention: TimeInterval = EvidenceStore.defaultRetention, maxRecords: Int = EvidenceStore.defaultMaxRecords, maxStoreBytes: Int = EvidenceStore.defaultMaxStoreBytes, now: @escaping () -> Date = Date.init) {
        self.retention = retention
        self.maxRecords = maxRecords
        self.maxStoreBytes = maxStoreBytes
        self.now = now
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
            self.fileURL = base.appendingPathComponent("FileMCP/evidence-v1.json")
        }
        do {
            try loadAndRecover()
        } catch {
            unavailableReason = error.localizedDescription
        }
    }

    static func newEvidenceID() -> String { "ev_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }
    static func workspaceFingerprint(_ path: String) -> String { sha256Tagged(URL(fileURLWithPath: path).standardizedFileURL.path) }

    func begin(_ record: EvidenceRecord) throws {
        try withLock {
            try requireAvailable()
            var candidate = cleanup(records)
            if candidate.count >= maxRecords {
                candidate = evictTerminal(candidate, targetCount: maxRecords - 1)
            }
            guard candidate.count < maxRecords else { throw MCPServerError.operationFailed("Evidence record-count quota is exhausted by active records") }
            candidate.append(record)
            try persist(candidate)
            records = candidate
        }
    }

    func complete(_ completion: EvidenceRecord) throws {
        if let source = completion.sourceStateJSON, source.utf8.count > Self.maxSourceStateJSONBytes {
            throw MCPServerError.operationFailed("Evidence SourceStateRef metadata exceeds \(Self.maxSourceStateJSONBytes) bytes")
        }
        try withLock {
            try requireAvailable()
            guard let index = records.firstIndex(where: { $0.evidenceID == completion.evidenceID && $0.operationState == "running" }) else {
                throw MCPServerError.operationFailed("Evidence terminal write failed because the running record is unavailable")
            }
            var candidate = records
            candidate[index] = completion
            candidate = cleanup(candidate)
            try persist(candidate)
            records = candidate
        }
    }

    func get(_ evidenceID: String) throws -> EvidenceRecord? {
        guard Self.isEvidenceID(evidenceID) else { throw MCPServerError.invalidArguments("Malformed evidence_id") }
        return try withLock {
            try requireAvailable()
            return records.first(where: { $0.evidenceID == evidenceID })
        }
    }

    func countForTest() throws -> Int { try withLock { try requireAvailable(); return records.count } }
    var pathForTest: URL { fileURL }

    private func loadAndRecover() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { records = []; return }
        let data = try Data(contentsOf: fileURL)
        guard data.count <= maxStoreBytes else { throw MCPServerError.operationFailed("Evidence storage-size quota is exhausted") }
        let snapshot = try JSONDecoder().decode(EvidenceSnapshot.self, from: data)
        guard snapshot.schemaVersion == Self.schemaVersion else { throw MCPServerError.operationFailed("Unsupported evidence snapshot schema version") }
        var recovered = cleanup(snapshot.records)
        let nowMs = Int64(now().timeIntervalSince1970 * 1000)
        var changed = recovered.count != snapshot.records.count
        for index in recovered.indices where recovered[index].operationState == "running" {
            recovered[index].operationState = "unknown"
            recovered[index].verificationState = "unknown"
            recovered[index].endedEpochMs = recovered[index].endedEpochMs ?? nowMs
            changed = true
        }
        if recovered.count > maxRecords { recovered = evictTerminal(recovered, targetCount: maxRecords); changed = true }
        if changed { try persist(recovered) }
        records = recovered
    }

    private func cleanup(_ input: [EvidenceRecord]) -> [EvidenceRecord] {
        let cutoff = Int64((now().timeIntervalSince1970 - retention) * 1000)
        return input.filter { $0.startedEpochMs >= cutoff }
    }

    private func evictTerminal(_ input: [EvidenceRecord], targetCount: Int) -> [EvidenceRecord] {
        guard input.count > targetCount else { return input }
        let removable = input.enumerated().filter { $0.element.operationState != "running" }.sorted {
            let left = $0.element.endedEpochMs ?? $0.element.startedEpochMs
            let right = $1.element.endedEpochMs ?? $1.element.startedEpochMs
            return left == right ? $0.element.evidenceID < $1.element.evidenceID : left < right
        }
        let remove = Set(removable.prefix(input.count - targetCount).map(\.offset))
        return input.enumerated().compactMap { remove.contains($0.offset) ? nil : $0.element }
    }

    private func persist(_ candidate: [EvidenceRecord]) throws {
        let snapshot = EvidenceSnapshot(schemaVersion: Self.schemaVersion, records: candidate)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        guard data.count <= maxStoreBytes else { throw MCPServerError.operationFailed("Evidence storage-size quota is exhausted") }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func requireAvailable() throws {
        if let unavailableReason { throw MCPServerError.operationFailed("Evidence store unavailable: \(unavailableReason)") }
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }

    private static func isEvidenceID(_ value: String) -> Bool {
        guard value.count == 35, value.hasPrefix("ev_") else { return false }
        return value.dropFirst(3).allSatisfy { $0.isHexDigit }
    }

    private static func sha256Tagged(_ value: String) -> String {
        "sha256:" + SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct EvidenceRun {
    let evidenceID: String
    let operationID: String
    let toolName: String
    let request: EvidenceRequestSpec
    let durableStarted: Bool
    let startedEpochMs: Int64
    let preSourceStateID: String?
    let preProjectContextDigest: String?
    let blockedBeforeDispatch: Bool
    let blockReason: String?
}

final class EvidenceCoordinator {
    static let metadataSchemaVersion = "1.0.0"
    private let store: EvidenceStore
    private let tools: LocalTools
    private let policy: ServerPolicy
    private let workspaceFingerprint: String
    private let log: (String) -> Void

    init(store: EvidenceStore, tools: LocalTools, policy: ServerPolicy, workspaceFingerprint: String, log: @escaping (String) -> Void) {
        self.store = store; self.tools = tools; self.policy = policy; self.workspaceFingerprint = workspaceFingerprint; self.log = log
    }

    func begin(request: EvidenceRequestSpec?, operationID: String, toolName: String) -> EvidenceRun? {
        guard let request else { return nil }
        let evidenceID = EvidenceStore.newEvidenceID()
        let started = Int64(Date().timeIntervalSince1970 * 1000)
        let snapshot = policy.capture()
        var durable = true
        do {
            try store.begin(EvidenceRecord(
                evidenceID: evidenceID, operationID: operationID, workspaceFingerprint: workspaceFingerprint,
                toolName: toolName, criterionID: request.criterionID, startedEpochMs: started, endedEpochMs: nil,
                operationState: "running", verificationState: "not-run", backendID: "host-native",
                sourceStateJSON: nil, sourceStateID: nil, projectContextDigest: nil,
                policyGeneration: snapshot.generation, policyHash: snapshot.hash,
                catalogHash: CanonicalToolCatalog.shared.catalogHash, catalogVersion: CanonicalToolCatalog.shared.catalogVersion,
                exitCode: nil, timedOut: false, cancelled: false, truncated: false))
        } catch {
            durable = false
            log("[Evidence] durable begin unavailable: \(type(of: error))\n")
        }
        var preSource: String?
        var preContext: String?
        var preAvailable = true
        if request.criterionID == "process.exit_zero", let repoPath = request.repoPath {
            do {
                let source = try tools.captureSourceStateRef(repoPath: repoPath, relevantPaths: request.relevantPaths)
                preSource = source["source_state_id"] as? String
                preContext = try tools.captureProjectContextDigest(repoPath: repoPath)
                if preSource == nil || preContext == nil { throw MCPServerError.operationFailed("Pre-execution freshness identity unavailable") }
            } catch {
                preAvailable = false
                log("[Evidence] pre-execution freshness unavailable: \(type(of: error))\n")
            }
        }
        let blocked = request.required && (!durable || !preAvailable)
        let reason = !durable ? "durable_store_unavailable" : (!preAvailable ? "freshness_precondition_unavailable" : nil)
        return EvidenceRun(evidenceID: evidenceID, operationID: operationID, toolName: toolName, request: request, durableStarted: durable, startedEpochMs: started, preSourceStateID: preSource, preProjectContextDigest: preContext, blockedBeforeDispatch: blocked, blockReason: reason)
    }

    func complete(run: EvidenceRun?, isError: Bool, structuredContent: [String: Any]?, context: ToolExecutionContext?) -> [String: Any]? {
        guard let run else { return nil }
        let evaluation = run.blockedBeforeDispatch
            ? EvidenceEvaluation(operationState: "not-run", verificationState: "blocked", exitCode: nil, timedOut: false, cancelled: false, truncated: false)
            : EvidenceEvaluator.evaluate(toolName: run.toolName, criterionID: run.request.criterionID, isError: isError, structuredContent: structuredContent, context: context)
        var sourceState: [String: Any]?
        var projectContextDigest: String?
        var sourceBinding = run.request.repoPath == nil ? "none" : "current"
        if !run.blockedBeforeDispatch, let repoPath = run.request.repoPath {
            do {
                sourceState = try tools.captureSourceStateRef(repoPath: repoPath, relevantPaths: run.request.relevantPaths)
                projectContextDigest = try tools.captureProjectContextDigest(repoPath: repoPath)
            } catch {
                sourceBinding = "unavailable"
                log("[Evidence] source/context capture unavailable: \(type(of: error))\n")
            }
        }
        var verification = evaluation.verificationState
        if verification == "passed", sourceBinding == "unavailable" { verification = "unknown" }
        if verification == "passed", run.request.criterionID == "process.exit_zero", run.request.repoPath != nil {
            let postSource = sourceState?["source_state_id"] as? String
            if run.preSourceStateID == nil || run.preProjectContextDigest == nil || postSource == nil || projectContextDigest == nil {
                verification = "unknown"
            } else if run.preSourceStateID != postSource || run.preProjectContextDigest != projectContextDigest {
                verification = "stale"
            }
        }
        let finalPolicy = policy.capture()
        var durable = run.durableStarted
        let sourceJSON: String? = sourceState.flatMap { value in
            guard JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        if durable {
            do {
                try store.complete(EvidenceRecord(
                    evidenceID: run.evidenceID, operationID: run.operationID, workspaceFingerprint: workspaceFingerprint,
                    toolName: run.toolName, criterionID: run.request.criterionID, startedEpochMs: run.startedEpochMs,
                    endedEpochMs: Int64(Date().timeIntervalSince1970 * 1000), operationState: evaluation.operationState,
                    verificationState: verification, backendID: "host-native", sourceStateJSON: sourceJSON,
                    sourceStateID: sourceState?["source_state_id"] as? String, projectContextDigest: projectContextDigest,
                    policyGeneration: finalPolicy.generation, policyHash: finalPolicy.hash,
                    catalogHash: CanonicalToolCatalog.shared.catalogHash, catalogVersion: CanonicalToolCatalog.shared.catalogVersion,
                    exitCode: evaluation.exitCode, timedOut: evaluation.timedOut, cancelled: evaluation.cancelled, truncated: evaluation.truncated))
            } catch {
                durable = false
                if ["passed", "failed", "stale"].contains(verification) { verification = "unknown" }
                log("[Evidence] durable completion unavailable: \(type(of: error))\n")
            }
        } else if ["passed", "failed", "stale"].contains(verification) {
            verification = "unknown"
        }
        return [
            "schema_version": Self.metadataSchemaVersion, "evidence_id": run.evidenceID, "operation_id": run.operationID,
            "storage_status": durable ? "durable" : "unavailable", "operation_state": evaluation.operationState,
            "verification_state": verification, "criterion_id": run.request.criterionID, "source_binding": sourceBinding,
            "source_state_id": sourceState?["source_state_id"] ?? NSNull(), "project_context_digest": projectContextDigest ?? NSNull(),
            "policy_generation": finalPolicy.generation, "policy_hash": finalPolicy.hash,
            "catalog_hash": CanonicalToolCatalog.shared.catalogHash, "catalog_version": CanonicalToolCatalog.shared.catalogVersion,
            "block_reason": run.blockReason ?? NSNull(),
        ]
    }

    func status(evidenceID: String, repoPath: String?, relevantPaths: [String]) throws -> [String: Any] {
        guard let record = try store.get(evidenceID), record.workspaceFingerprint == workspaceFingerprint else {
            throw MCPServerError.notFound("Evidence record not found")
        }
        let currentPolicy = policy.capture()
        var freshness = "current"
        var reason = "none"
        if record.catalogHash != CanonicalToolCatalog.shared.catalogHash || record.catalogVersion != CanonicalToolCatalog.shared.catalogVersion || record.policyGeneration != currentPolicy.generation || record.policyHash != currentPolicy.hash {
            freshness = "stale"; reason = "policy_or_catalog_changed"
        }
        var currentSource: String?
        var currentContext: String?
        if record.sourceStateID != nil || record.projectContextDigest != nil {
            guard let repoPath, !repoPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if freshness != "stale" { freshness = "unknown"; reason = "source_scope_required" }
                return statusDictionary(record: record, verification: effectiveVerification(record: record, freshness: freshness), freshness: freshness, reason: reason, currentSource: nil, currentContext: nil)
            }
            do {
                let source = try tools.captureSourceStateRef(repoPath: repoPath, relevantPaths: relevantPaths)
                currentSource = source["source_state_id"] as? String
                currentContext = try tools.captureProjectContextDigest(repoPath: repoPath)
                if (record.sourceStateID != nil && record.sourceStateID != currentSource) || (record.projectContextDigest != nil && record.projectContextDigest != currentContext) {
                    freshness = "stale"; reason = "source_or_context_changed"
                }
            } catch {
                if freshness != "stale" { freshness = "unknown"; reason = "source_recompute_failed" }
            }
        }
        return statusDictionary(record: record, verification: effectiveVerification(record: record, freshness: freshness), freshness: freshness, reason: reason, currentSource: currentSource, currentContext: currentContext)
    }

    private func effectiveVerification(record: EvidenceRecord, freshness: String) -> String {
        if record.operationState == "unknown" { return "unknown" }
        if freshness == "stale", ["passed", "failed"].contains(record.verificationState) { return "stale" }
        if freshness == "unknown", ["passed", "failed"].contains(record.verificationState) { return "unknown" }
        return record.verificationState
    }

    private func statusDictionary(record: EvidenceRecord, verification: String, freshness: String, reason: String, currentSource: String?, currentContext: String?) -> [String: Any] {
        [
            "schema_version": Self.metadataSchemaVersion, "evidence_id": record.evidenceID, "operation_id": record.operationID,
            "tool_name": record.toolName, "criterion_id": record.criterionID, "operation_state": record.operationState,
            "persisted_verification_state": record.verificationState, "verification_state": verification,
            "freshness_state": freshness, "freshness_reason": reason, "source_state_id": record.sourceStateID ?? NSNull(),
            "current_source_state_id": currentSource ?? NSNull(), "project_context_digest": record.projectContextDigest ?? NSNull(),
            "current_project_context_digest": currentContext ?? NSNull(), "policy_generation": record.policyGeneration,
            "policy_hash": record.policyHash, "catalog_hash": record.catalogHash, "catalog_version": record.catalogVersion,
            "backend_id": record.backendID, "exit_code": record.exitCode ?? NSNull(), "timed_out": record.timedOut,
            "cancelled": record.cancelled, "truncated": record.truncated, "started_epoch_ms": record.startedEpochMs,
            "ended_epoch_ms": record.endedEpochMs ?? NSNull(),
        ]
    }
}
