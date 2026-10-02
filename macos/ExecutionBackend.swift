import Foundation

enum ExecutionBackendCapabilities {
    static let process = "process"
    static let pty = "pty"
    static let workspaceMapping = "workspace_mapping"
    static let environmentMediation = "environment_mediation"
    static let hostNetwork = "host_network"
    static let cleanup = "cleanup"
    static let isolation = "isolation"
    static let networkNone = "network_none"
    static let networkEnabled = "network_enabled"
    static let digestPinnedImage = "digest_pinned_image"
    static let resourceLimits = "resource_limits"
}

struct ExecutionBackendDescriptor {
    let id: String
    let version: String
    let capabilities: [String]
    let workspaceMode: String
    let environmentMode: String
    let networkMode: String
    let resourceMode: String
}

struct ExecutionBackendHealth {
    let available: Bool
    let state: String
    let detail: String?
}

struct ExecutionBackendEvidenceIdentity {
    let backendID: String
    let metadata: [String: String]
}

struct ExecutionProcessRequest {
    let executable: String
    let arguments: [String]
    let cwd: String
    let environmentOverrides: [String: String]
    let timeoutSeconds: Int
    let outputLimitBytes: Int
}

protocol ExecutionBackend: AnyObject {
    var descriptor: ExecutionBackendDescriptor { get }
    var health: ExecutionBackendHealth { get }
    var evidenceIdentity: ExecutionBackendEvidenceIdentity { get }

    func runProcess(_ request: ExecutionProcessRequest, shouldCancel: (() -> Bool)?) throws -> ProcessResult

    func startPty(
        executable: String,
        arguments: [String],
        cwd: String,
        environmentOverrides: [String: String],
        columns: Int,
        rows: Int,
        idleTTLSeconds: Int,
        maxLifetimeSeconds: Int,
        spillOutput: Bool
    ) throws -> [String: Any]

    func readPty(sessionID: String, cursor: String, maxBytes: Int, context: ToolExecutionContext?) throws -> [String: Any]
    func writePty(sessionID: String, data: String) throws -> [String: Any]
    func resizePty(sessionID: String, columns: Int, rows: Int) throws -> [String: Any]
    func signalPty(sessionID: String, signal: String) throws -> [String: Any]
    func stopPty(sessionID: String) throws -> [String: Any]
    func listPty() throws -> [String: Any]
    func stopAll()
}

enum ExecutionBackendContracts {
    private static let identifierPattern = "^[a-z0-9][a-z0-9._-]{0,63}$"

    static func validate(_ descriptor: ExecutionBackendDescriptor) throws {
        guard descriptor.id.range(of: identifierPattern, options: .regularExpression) != nil else {
            throw MCPServerError.operationFailed("Execution backend identity is invalid")
        }
        guard !descriptor.version.isEmpty,
              descriptor.version.count <= 64,
              descriptor.version.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw MCPServerError.operationFailed("Execution backend version is invalid")
        }
        guard !descriptor.capabilities.isEmpty, descriptor.capabilities.count <= 32 else {
            throw MCPServerError.operationFailed("Execution backend capabilities are invalid")
        }
        var seen = Set<String>()
        for capability in descriptor.capabilities {
            guard capability.range(of: identifierPattern, options: .regularExpression) != nil,
                  seen.insert(capability).inserted else {
                throw MCPServerError.operationFailed("Execution backend capability set is invalid")
            }
        }
        for mode in [
            descriptor.workspaceMode,
            descriptor.environmentMode,
            descriptor.networkMode,
            descriptor.resourceMode,
        ] {
            guard mode.range(of: identifierPattern, options: .regularExpression) != nil else {
                throw MCPServerError.operationFailed("Execution backend descriptor modes are invalid")
            }
        }
    }

    static func validate(_ health: ExecutionBackendHealth) throws {
        guard ["ready", "unavailable", "degraded", "disposed"].contains(health.state) else {
            throw MCPServerError.operationFailed("Execution backend health state is invalid")
        }
        if health.available && ["unavailable", "disposed"].contains(health.state) {
            throw MCPServerError.operationFailed("Execution backend health is inconsistent")
        }
    }

    static func validate(_ identity: ExecutionBackendEvidenceIdentity) throws {
        guard identity.backendID.range(of: identifierPattern, options: .regularExpression) != nil else {
            throw MCPServerError.operationFailed("Execution backend evidence identity is invalid")
        }
        guard identity.metadata.count <= 32 else {
            throw MCPServerError.operationFailed("Execution backend evidence metadata is too large")
        }
        for (key, value) in identity.metadata {
            guard key.range(of: identifierPattern, options: .regularExpression) != nil else {
                throw MCPServerError.operationFailed("Execution backend evidence metadata key is invalid")
            }
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  value.count <= 1024,
                  !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw MCPServerError.operationFailed("Execution backend evidence metadata value is invalid")
            }
        }
    }

    static func requireCapability(_ descriptor: ExecutionBackendDescriptor, _ capability: String) throws {
        try validate(descriptor)
        guard descriptor.capabilities.contains(capability) else {
            throw MCPServerError.operationFailed("Execution backend does not support required capability: \(capability)")
        }
    }

    static func validate(_ result: ProcessResult) throws {
        if result.timedOut && result.cancelled {
            throw MCPServerError.operationFailed("Execution backend returned an invalid process terminal state")
        }
        guard result.stdoutOmittedBytes >= 0, result.stderrOmittedBytes >= 0 else {
            throw MCPServerError.operationFailed("Execution backend returned invalid omitted-byte counters")
        }
        guard result.stdoutTruncated == (result.stdoutOmittedBytes > 0),
              result.stderrTruncated == (result.stderrOmittedBytes > 0) else {
            throw MCPServerError.operationFailed("Execution backend returned inconsistent truncation metadata")
        }
    }

    static func attachMetadata(_ result: [String: Any], descriptor: ExecutionBackendDescriptor) throws -> [String: Any] {
        try validate(descriptor)
        var output = result
        output["backend_id"] = descriptor.id
        output["backend_version"] = descriptor.version
        output["backend_capabilities"] = descriptor.capabilities.sorted()
        output["backend_workspace_mode"] = descriptor.workspaceMode
        output["backend_environment_mode"] = descriptor.environmentMode
        output["backend_network_mode"] = descriptor.networkMode
        output["backend_resource_mode"] = descriptor.resourceMode
        return output
    }
}

final class HostExecutionBackend: ExecutionBackend {
    static let backendID = "host-native"
    static let backendVersion = "1.0.0"

    private static let hostDescriptor = ExecutionBackendDescriptor(
        id: backendID,
        version: backendVersion,
        capabilities: [
            ExecutionBackendCapabilities.process,
            ExecutionBackendCapabilities.pty,
            ExecutionBackendCapabilities.workspaceMapping,
            ExecutionBackendCapabilities.environmentMediation,
            ExecutionBackendCapabilities.hostNetwork,
            ExecutionBackendCapabilities.cleanup,
        ],
        workspaceMode: "host-contained",
        environmentMode: "mediated",
        networkMode: "host",
        resourceMode: "host-process"
    )

    private static let hostEvidenceIdentity = ExecutionBackendEvidenceIdentity(
        backendID: backendID,
        metadata: [
            "workspace_mode": "host-contained",
            "network_policy": "host",
            "resource_policy": "host-process",
        ]
    )

    private let resolver: SafePathResolver
    private let environmentAuthority: ExecProcessEnvironmentAuthority
    private let pty: PersistentPtyService
    private var disposed = false
    private let lock = NSLock()

    init(
        resolver: SafePathResolver,
        environmentAuthority: ExecProcessEnvironmentAuthority,
        artifactFactory: @escaping () throws -> ArtifactContentStore
    ) throws {
        try ExecutionBackendContracts.validate(Self.hostDescriptor)
        try ExecutionBackendContracts.validate(Self.hostEvidenceIdentity)
        self.resolver = resolver
        self.environmentAuthority = environmentAuthority
        self.pty = try PersistentPtyService(
            resolver: resolver,
            environmentAuthority: environmentAuthority,
            artifactFactory: artifactFactory
        )
    }

    var descriptor: ExecutionBackendDescriptor { Self.hostDescriptor }
    var evidenceIdentity: ExecutionBackendEvidenceIdentity { Self.hostEvidenceIdentity }

    var health: ExecutionBackendHealth {
        lock.lock()
        let isDisposed = disposed
        lock.unlock()
        return isDisposed
            ? ExecutionBackendHealth(available: false, state: "disposed", detail: nil)
            : ExecutionBackendHealth(available: true, state: "ready", detail: nil)
    }

    func runProcess(_ request: ExecutionProcessRequest, shouldCancel: (() -> Bool)?) throws -> ProcessResult {
        try throwIfDisposed()
        let workdir = try resolver.resolve(request.cwd)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workdir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw MCPServerError.invalidPath("No such working directory: \(request.cwd.isEmpty ? "." : request.cwd)")
        }
        let environment = try environmentAuthority.build(overrides: request.environmentOverrides)
        let result = try ProcessRunner.run(
            executable: request.executable,
            arguments: request.arguments,
            cwd: workdir.path,
            environment: environment,
            timeoutSeconds: request.timeoutSeconds,
            outputLimitBytes: request.outputLimitBytes,
            shouldCancel: shouldCancel
        )
        try ExecutionBackendContracts.validate(result)
        return result
    }

    func startPty(
        executable: String,
        arguments: [String],
        cwd: String,
        environmentOverrides: [String: String],
        columns: Int,
        rows: Int,
        idleTTLSeconds: Int,
        maxLifetimeSeconds: Int,
        spillOutput: Bool
    ) throws -> [String: Any] {
        try throwIfDisposed()
        return try pty.start(
            executable: executable,
            arguments: arguments,
            cwd: cwd,
            environmentOverrides: environmentOverrides,
            columns: columns,
            rows: rows,
            idleTTLSeconds: idleTTLSeconds,
            maxLifetimeSeconds: maxLifetimeSeconds,
            spillOutput: spillOutput
        )
    }

    func readPty(sessionID: String, cursor: String, maxBytes: Int, context: ToolExecutionContext?) throws -> [String: Any] {
        try throwIfDisposed()
        return try pty.read(sessionID: sessionID, cursor: cursor, maxBytes: maxBytes, context: context)
    }

    func writePty(sessionID: String, data: String) throws -> [String: Any] {
        try throwIfDisposed()
        return try pty.write(sessionID: sessionID, data: data)
    }

    func resizePty(sessionID: String, columns: Int, rows: Int) throws -> [String: Any] {
        try throwIfDisposed()
        return try pty.resize(sessionID: sessionID, columns: columns, rows: rows)
    }

    func signalPty(sessionID: String, signal: String) throws -> [String: Any] {
        try throwIfDisposed()
        return try pty.signal(sessionID: sessionID, signal: signal)
    }

    func stopPty(sessionID: String) throws -> [String: Any] {
        try throwIfDisposed()
        return try pty.stop(sessionID: sessionID)
    }

    func listPty() throws -> [String: Any] {
        try throwIfDisposed()
        return pty.list()
    }

    func stopAll() {
        lock.lock()
        let isDisposed = disposed
        lock.unlock()
        if !isDisposed { pty.stopAll() }
    }

    private func throwIfDisposed() throws {
        lock.lock()
        let isDisposed = disposed
        lock.unlock()
        if isDisposed {
            throw MCPServerError.operationFailed("Execution backend is disposed")
        }
    }

    deinit {
        lock.lock()
        disposed = true
        lock.unlock()
        pty.stopAll()
    }
}
