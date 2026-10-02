import Foundation

struct DockerExecutionBackendConfiguration {
    var enabled = false
    var image = ""
    var allowedImages: [String] = []
    var networkEnabled = false
    var cpuLimit = 2.0
    var memoryBytes: Int64 = 2 * 1024 * 1024 * 1024
    var pidsLimit = 128
    var user = "1000:1000"
    var startupTimeoutSeconds = 30
    var idleTTLSeconds = 900
    var maxLifetimeSeconds = 7200

    func normalized() throws -> DockerExecutionBackendConfiguration {
        var copy = self
        copy.image = image.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.allowedImages = Array(Set(
            allowedImages
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )).sorted()
        copy.user = user.trimmingCharacters(in: .whitespacesAndNewlines)
        try DockerExecutionBackend.validateConfiguration(copy)
        return copy
    }
}

protocol DockerCliRunning: AnyObject {
    var ptyExecutable: String { get }
    func run(
        arguments: [String],
        environment: [String: String],
        timeoutSeconds: Int,
        outputLimitBytes: Int,
        shouldCancel: (() -> Bool)?
    ) throws -> ProcessResult
}

final class ProcessDockerCliRunner: DockerCliRunning {
    let ptyExecutable: String

    init() throws {
        let candidates = [
            "/Applications/Docker.app/Contents/Resources/bin/docker",
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
        ]
        guard let resolved = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw MCPServerError.operationFailed("Docker CLI is unavailable")
        }
        ptyExecutable = resolved
    }

    func run(
        arguments: [String],
        environment: [String: String],
        timeoutSeconds: Int,
        outputLimitBytes: Int,
        shouldCancel: (() -> Bool)?
    ) throws -> ProcessResult {
        try ProcessRunner.run(
            executable: ptyExecutable,
            arguments: arguments,
            environment: environment,
            timeoutSeconds: timeoutSeconds,
            outputLimitBytes: outputLimitBytes,
            shouldCancel: shouldCancel
        )
    }
}

final class DockerExecutionBackend: ExecutionBackend {
    static let backendID = "docker-isolated"
    static let backendVersion = "1.0.0"

    private static let workspaceDestination = "/workspace"
    private static let ownerLabelKey = "io.filemcp.owner"
    private static let ownerLabelValue = "filemcp"
    private static let backendLabelKey = "io.filemcp.backend"
    private static let workspaceLabelKey = "io.filemcp.workspace"
    private static let leaseLabelKey = "io.filemcp.lease"
    private static let dockerControlOutputLimit = 256_000
    private static let dockerControlEnvironmentNames = [
        "DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH", "DOCKER_CONFIG",
        "HOME", "USERPROFILE", "HOMEDRIVE", "HOMEPATH", "XDG_CONFIG_HOME",
    ]
    private static let digestPinnedImagePattern = "^[^\\s@]{1,448}@sha256:[0-9a-f]{64}$"
    private static let containerIDPattern = "^[0-9a-f]{12,64}$"
    private static let userPattern = "^[A-Za-z0-9_.-]{1,64}(?::[A-Za-z0-9_.-]{1,64})?$"

    private let resolver: SafePathResolver
    private let environmentAuthority: ExecProcessEnvironmentAuthority
    private let dockerClientEnvironmentAuthority: ExecProcessEnvironmentAuthority
    private let artifactStore: ArtifactContentStore
    private let pty: PersistentPtyService
    private let docker: DockerCliRunning
    private let configuration: DockerExecutionBackendConfiguration
    private let workspaceAuthorityID: String
    private let imageDigest: String
    private let containerLock = NSLock()
    private let healthLock = NSLock()
    private let maintenanceTimer: DispatchSourceTimer
    private var containerID: String?
    private var containerCreatedAt: Date?
    private var lastActivityAt: Date?
    private var leaseID: String?
    private var disposed = false
    private var backendHealth = ExecutionBackendHealth(available: true, state: "degraded", detail: "not-probed")

    init(
        resolver: SafePathResolver,
        environmentAuthority: ExecProcessEnvironmentAuthority,
        artifactStore: ArtifactContentStore,
        configuration: DockerExecutionBackendConfiguration,
        allowNetworkEnabled: Bool,
        docker: DockerCliRunning? = nil
    ) throws {
        self.resolver = resolver
        self.environmentAuthority = environmentAuthority
        self.artifactStore = artifactStore
        let normalized = try configuration.normalized()
        guard normalized.enabled else {
            throw MCPServerError.operationFailed("Docker execution backend configuration is not enabled")
        }
        if normalized.networkEnabled && !allowNetworkEnabled {
            throw MCPServerError.operationFailed("Docker network-enabled execution requires explicit custom local network policy")
        }
        self.configuration = normalized
        self.workspaceAuthorityID = ArtifactContentStore.workspaceAuthorityID(resolver.root)
        guard let at = normalized.image.range(of: "@") else {
            throw MCPServerError.operationFailed("Docker backend image must be digest pinned")
        }
        self.imageDigest = String(normalized.image[at.upperBound...])
        if let docker {
            self.docker = docker
        } else {
            self.docker = try ProcessDockerCliRunner()
        }
        self.dockerClientEnvironmentAuthority = try ExecProcessEnvironmentAuthority(
            patterns: environmentAuthority.patterns,
            blockedOverrideNames: Self.dockerControlEnvironmentNames
        )
        self.pty = try PersistentPtyService(
            resolver: resolver,
            environmentAuthority: dockerClientEnvironmentAuthority,
            artifactFactory: { artifactStore }
        )
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        self.maintenanceTimer = timer

        try ExecutionBackendContracts.validate(descriptor)
        try ExecutionBackendContracts.validate(evidenceIdentity)

        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in
            self?.sweepExpiredContainer()
        }
        timer.resume()
    }

    var descriptor: ExecutionBackendDescriptor {
        var capabilities = [
            ExecutionBackendCapabilities.process,
            ExecutionBackendCapabilities.pty,
            ExecutionBackendCapabilities.workspaceMapping,
            ExecutionBackendCapabilities.environmentMediation,
            ExecutionBackendCapabilities.cleanup,
            ExecutionBackendCapabilities.isolation,
            ExecutionBackendCapabilities.digestPinnedImage,
            ExecutionBackendCapabilities.resourceLimits,
        ]
        capabilities.append(configuration.networkEnabled
            ? ExecutionBackendCapabilities.networkEnabled
            : ExecutionBackendCapabilities.networkNone)
        return ExecutionBackendDescriptor(
            id: Self.backendID,
            version: Self.backendVersion,
            capabilities: capabilities,
            workspaceMode: "container-mounted",
            environmentMode: "mediated",
            networkMode: configuration.networkEnabled ? "bridge" : "none",
            resourceMode: "container-capped"
        )
    }

    var health: ExecutionBackendHealth {
        healthLock.lock()
        defer { healthLock.unlock() }
        return disposed
            ? ExecutionBackendHealth(available: false, state: "disposed", detail: nil)
            : backendHealth
    }

    var evidenceIdentity: ExecutionBackendEvidenceIdentity {
        ExecutionBackendEvidenceIdentity(
            backendID: Self.backendID,
            metadata: [
                "image_ref": configuration.image,
                "image_digest": imageDigest,
                "workspace_mode": "container-mounted",
                "network_policy": configuration.networkEnabled ? "bridge" : "none",
                "resource_policy": "cpu=\(formatCPU(configuration.cpuLimit));memory=\(configuration.memoryBytes);pids=\(configuration.pidsLimit)",
            ]
        )
    }

    func runProcess(_ request: ExecutionProcessRequest, shouldCancel: (() -> Bool)?) throws -> ProcessResult {
        try throwIfDisposed()
        let containerCWD = try containerWorkingDirectory(request.cwd)
        let isolatedEnvironment = try buildContainerEnvironment(request.environmentOverrides)
        let dockerEnvironment = try dockerClientEnvironment(request.environmentOverrides)
        let container = try ensureContainer(shouldCancel: shouldCancel)

        var arguments = ["exec", "--workdir", containerCWD]
        appendContainerEnvironmentArguments(&arguments, environment: isolatedEnvironment)
        arguments.append(container)
        arguments.append(request.executable)
        arguments.append(contentsOf: request.arguments)
        touch()

        let result = try docker.run(
            arguments: arguments,
            environment: dockerEnvironment,
            timeoutSeconds: request.timeoutSeconds,
            outputLimitBytes: request.outputLimitBytes,
            shouldCancel: shouldCancel
        )
        try ExecutionBackendContracts.validate(result)
        if result.exitCode == 125 && !result.timedOut && !result.cancelled {
            setHealth(ExecutionBackendHealth(available: true, state: "degraded", detail: "docker exec returned infrastructure error"))
        } else {
            setHealth(ExecutionBackendHealth(available: true, state: "ready", detail: nil))
        }
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
        let containerCWD = try containerWorkingDirectory(cwd)
        let isolatedEnvironment = try buildContainerEnvironment(environmentOverrides)
        _ = try dockerClientEnvironment(environmentOverrides)
        let container = try ensureContainer(shouldCancel: nil)

        var dockerArguments = ["exec", "-it", "--workdir", containerCWD]
        appendContainerEnvironmentArguments(&dockerArguments, environment: isolatedEnvironment)
        dockerArguments.append(container)
        dockerArguments.append(executable)
        dockerArguments.append(contentsOf: arguments)
        touch()

        let result = try pty.start(
            executable: docker.ptyExecutable,
            arguments: dockerArguments,
            cwd: "",
            environmentOverrides: environmentOverrides,
            columns: columns,
            rows: rows,
            idleTTLSeconds: idleTTLSeconds,
            maxLifetimeSeconds: maxLifetimeSeconds,
            spillOutput: spillOutput
        )
        setHealth(ExecutionBackendHealth(available: true, state: "ready", detail: nil))
        return result
    }

    func readPty(sessionID: String, cursor: String, maxBytes: Int, context: ToolExecutionContext?) throws -> [String: Any] {
        try throwIfDisposed()
        touch()
        return try pty.read(sessionID: sessionID, cursor: cursor, maxBytes: maxBytes, context: context)
    }

    func writePty(sessionID: String, data: String) throws -> [String: Any] {
        try throwIfDisposed()
        touch()
        return try pty.write(sessionID: sessionID, data: data)
    }

    func resizePty(sessionID: String, columns: Int, rows: Int) throws -> [String: Any] {
        try throwIfDisposed()
        touch()
        return try pty.resize(sessionID: sessionID, columns: columns, rows: rows)
    }

    func signalPty(sessionID: String, signal: String) throws -> [String: Any] {
        try throwIfDisposed()
        touch()
        return try pty.signal(sessionID: sessionID, signal: signal)
    }

    func stopPty(sessionID: String) throws -> [String: Any] {
        try throwIfDisposed()
        touch()
        return try pty.stop(sessionID: sessionID)
    }

    func listPty() throws -> [String: Any] {
        try throwIfDisposed()
        touch()
        return pty.list()
    }

    func stopAll() {
        if isDisposed { return }
        pty.stopAll()
        removeCurrentContainerBestEffort()
    }

    deinit {
        healthLock.lock()
        disposed = true
        healthLock.unlock()
        maintenanceTimer.cancel()
        pty.stopAll()
        removeCurrentContainerBestEffort(ignoreDisposed: true)
    }

    static func validateConfiguration(_ configuration: DockerExecutionBackendConfiguration) throws {
        guard configuration.image.count <= 512,
              configuration.image.range(of: digestPinnedImagePattern, options: .regularExpression) != nil else {
            throw MCPServerError.operationFailed("Docker backend image must be an immutable digest-pinned reference")
        }
        guard (1...16).contains(configuration.allowedImages.count),
              configuration.allowedImages.allSatisfy({
                  $0.count <= 512 && $0.range(of: digestPinnedImagePattern, options: .regularExpression) != nil
              }) else {
            throw MCPServerError.operationFailed("Docker backend image allowlist must contain only bounded digest-pinned references")
        }
        guard configuration.allowedImages.contains(configuration.image) else {
            throw MCPServerError.operationFailed("Docker backend selected image is not in the local allowlist")
        }
        guard configuration.cpuLimit >= 0.1, configuration.cpuLimit <= 32 else {
            throw MCPServerError.operationFailed("Docker backend CPU limit must be 0.1..32")
        }
        guard configuration.memoryBytes >= 128 * 1024 * 1024,
              configuration.memoryBytes <= 64 * 1024 * 1024 * 1024 else {
            throw MCPServerError.operationFailed("Docker backend memory limit must be 128 MiB..64 GiB")
        }
        guard (16...4096).contains(configuration.pidsLimit) else {
            throw MCPServerError.operationFailed("Docker backend PID limit must be 16..4096")
        }
        guard configuration.user.range(of: userPattern, options: .regularExpression) != nil else {
            throw MCPServerError.operationFailed("Docker backend user must be an explicit bounded non-root user/group identity")
        }
        guard !["0", "0:0", "root", "root:root"].contains(configuration.user) else {
            throw MCPServerError.operationFailed("Docker backend refuses root container identity")
        }
        guard (1...ProcessRunner.maxCommandTimeoutSeconds).contains(configuration.startupTimeoutSeconds) else {
            throw MCPServerError.operationFailed("Docker backend startup timeout is out of range")
        }
        guard (60...86_400).contains(configuration.idleTTLSeconds) else {
            throw MCPServerError.operationFailed("Docker backend idle TTL must be 60..86400 seconds")
        }
        guard configuration.maxLifetimeSeconds >= configuration.idleTTLSeconds,
              configuration.maxLifetimeSeconds <= 604_800 else {
            throw MCPServerError.operationFailed("Docker backend max lifetime must be >= idle TTL and <= 604800 seconds")
        }
    }

    func buildCreateArgumentsForTest(containerName: String, leaseID: String) throws -> [String] {
        try buildCreateArguments(containerName: containerName, leaseID: leaseID, workspaceRoot: revalidatedWorkspaceRoot())
    }

    func buildExecArgumentsForTest(
        containerID: String,
        request: ExecutionProcessRequest,
        isolatedEnvironment: [String: String]
    ) throws -> [String] {
        var result = ["exec", "--workdir", try containerWorkingDirectory(request.cwd)]
        appendContainerEnvironmentArguments(&result, environment: isolatedEnvironment)
        result.append(containerID)
        result.append(request.executable)
        result.append(contentsOf: request.arguments)
        return result
    }

    func buildPtyExecArgumentsForTest(
        containerID: String,
        executable: String,
        arguments: [String],
        cwd: String,
        isolatedEnvironment: [String: String]
    ) throws -> [String] {
        var result = ["exec", "-it", "--workdir", try containerWorkingDirectory(cwd)]
        appendContainerEnvironmentArguments(&result, environment: isolatedEnvironment)
        result.append(containerID)
        result.append(executable)
        result.append(contentsOf: arguments)
        return result
    }

    private var isDisposed: Bool {
        healthLock.lock()
        defer { healthLock.unlock() }
        return disposed
    }

    private func ensureContainer(shouldCancel: (() -> Bool)?) throws -> String {
        containerLock.lock()
        defer { containerLock.unlock() }
        try throwIfDisposed()

        if containerExpired() {
            pty.stopAll()
            removeCurrentContainerLockedBestEffort()
        }
        if let containerID {
            lastActivityAt = Date()
            return containerID
        }

        _ = try runDockerChecked(
            arguments: ["version", "--format", "{{.Server.Version}}"],
            timeoutSeconds: min(configuration.startupTimeoutSeconds, 10),
            operation: "docker daemon probe",
            shouldCancel: shouldCancel
        )
        try resolvePinnedImage(shouldCancel: shouldCancel)
        try cleanupOwnedOrphans(shouldCancel: shouldCancel)

        let workspaceRoot = try revalidatedWorkspaceRoot()
        let lease = randomHex(byteCount: 12)
        let authority = workspaceAuthorityID.replacingOccurrences(of: "sha256:", with: "")
        let suffix = String(authority.prefix(12))
        let name = "filemcp-\(suffix)-\(lease.prefix(12))"
        let created = try runDockerChecked(
            arguments: try buildCreateArguments(containerName: name, leaseID: lease, workspaceRoot: workspaceRoot),
            timeoutSeconds: configuration.startupTimeoutSeconds,
            operation: "docker create",
            shouldCancel: shouldCancel
        )
        let id = created.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id.range(of: Self.containerIDPattern, options: .regularExpression) != nil else {
            throw MCPServerError.operationFailed("Docker backend create returned an invalid container identity")
        }

        do {
            _ = try runDockerChecked(
                arguments: ["start", id],
                timeoutSeconds: configuration.startupTimeoutSeconds,
                operation: "docker start",
                shouldCancel: shouldCancel
            )
            try verifyContainerSecurity(id: id, workspaceRoot: workspaceRoot, leaseID: lease, shouldCancel: shouldCancel)
        } catch {
            removeOwnedContainerBestEffort(id: id, shouldCancel: shouldCancel)
            throw error
        }

        containerID = id
        leaseID = lease
        containerCreatedAt = Date()
        lastActivityAt = containerCreatedAt
        setHealth(ExecutionBackendHealth(available: true, state: "ready", detail: nil))
        return id
    }

    private func buildCreateArguments(containerName: String, leaseID: String, workspaceRoot: String) throws -> [String] {
        guard !workspaceRoot.contains(","), !workspaceRoot.contains("\n"), !workspaceRoot.contains("\r") else {
            throw MCPServerError.operationFailed("Docker backend workspace mount source is not safely representable")
        }
        let mount = "type=bind,src=\(workspaceRoot),dst=\(Self.workspaceDestination),rw"
        return [
            "create",
            "--pull", "never",
            "--no-healthcheck",
            "--name", containerName,
            "--label", "\(Self.ownerLabelKey)=\(Self.ownerLabelValue)",
            "--label", "\(Self.backendLabelKey)=\(Self.backendID)",
            "--label", "\(Self.workspaceLabelKey)=\(workspaceAuthorityID)",
            "--label", "\(Self.leaseLabelKey)=\(leaseID)",
            "--read-only",
            "--cap-drop", "ALL",
            "--security-opt", "no-new-privileges",
            "--pids-limit", String(configuration.pidsLimit),
            "--cpus", formatCPU(configuration.cpuLimit),
            "--memory", String(configuration.memoryBytes),
            "--network", configuration.networkEnabled ? "bridge" : "none",
            "--user", configuration.user,
            "--tmpfs", "/tmp:rw,noexec,nosuid,nodev,size=67108864",
            "--mount", mount,
            configuration.image,
            "/bin/sh", "-c", "trap 'exit 0' TERM INT; while :; do sleep 3600; done",
        ]
    }

    private func resolvePinnedImage(shouldCancel: (() -> Bool)?) throws {
        let result = try runDockerChecked(
            arguments: ["image", "inspect", "--format", "{{json .RepoDigests}}", configuration.image],
            timeoutSeconds: configuration.startupTimeoutSeconds,
            operation: "docker image inspect",
            shouldCancel: shouldCancel
        )
        guard let data = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [String] else {
            throw MCPServerError.operationFailed("Docker backend image digest inspection returned invalid JSON")
        }
        guard array.contains(configuration.image) || array.contains(where: { $0.hasSuffix("@\(imageDigest)") }) else {
            throw MCPServerError.operationFailed("Docker backend local image does not resolve to the configured immutable digest")
        }
    }

    private func verifyContainerSecurity(
        id: String,
        workspaceRoot: String,
        leaseID: String,
        shouldCancel: (() -> Bool)?
    ) throws {
        let result = try runDockerChecked(
            arguments: ["inspect", "--format", "{{json .}}", id],
            timeoutSeconds: configuration.startupTimeoutSeconds,
            operation: "docker inspect",
            shouldCancel: shouldCancel
        )
        guard let data = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hostConfig = root["HostConfig"] as? [String: Any],
              let config = root["Config"] as? [String: Any],
              let labels = config["Labels"] as? [String: Any] else {
            throw MCPServerError.operationFailed("Docker backend container inspection is incomplete")
        }

        try requireLabel(labels, key: Self.ownerLabelKey, expected: Self.ownerLabelValue)
        try requireLabel(labels, key: Self.backendLabelKey, expected: Self.backendID)
        try requireLabel(labels, key: Self.workspaceLabelKey, expected: workspaceAuthorityID)
        try requireLabel(labels, key: Self.leaseLabelKey, expected: leaseID)

        let expectedNetwork = configuration.networkEnabled ? "bridge" : "none"
        guard (hostConfig["NetworkMode"] as? String) == expectedNetwork else {
            throw MCPServerError.operationFailed("Docker backend effective network policy does not match configured policy")
        }
        guard integer(hostConfig["PidsLimit"]) > 0,
              integer(hostConfig["Memory"]) > 0,
              integer(hostConfig["NanoCpus"]) > 0 else {
            throw MCPServerError.operationFailed("Docker backend effective resource caps are incomplete")
        }
        let capDrop = hostConfig["CapDrop"] as? [String] ?? []
        guard capDrop.contains(where: { $0.uppercased() == "ALL" }) else {
            throw MCPServerError.operationFailed("Docker backend effective capability drop is incomplete")
        }
        let securityOptions = hostConfig["SecurityOpt"] as? [String] ?? []
        guard securityOptions.contains(where: { $0.lowercased().contains("no-new-privileges") }) else {
            throw MCPServerError.operationFailed("Docker backend effective no-new-privileges policy is missing")
        }
        guard (config["User"] as? String) == configuration.user else {
            throw MCPServerError.operationFailed("Docker backend effective non-root user does not match local policy")
        }

        guard let mounts = root["Mounts"] as? [[String: Any]] else {
            throw MCPServerError.operationFailed("Docker backend inspection is missing mounts")
        }
        let binds = mounts.filter { (($0["Type"] as? String) ?? "").lowercased() == "bind" }
        guard binds.count == 1,
              let source = binds[0]["Source"] as? String,
              let destination = binds[0]["Destination"] as? String,
              bool(binds[0]["RW"]),
              destination == Self.workspaceDestination else {
            throw MCPServerError.operationFailed("Docker backend effective bind mounts are not limited to the workspace")
        }
        let canonicalSource = URL(fileURLWithPath: source).standardizedFileURL.resolvingSymlinksInPath().path
        let canonicalExpected = URL(fileURLWithPath: workspaceRoot).standardizedFileURL.resolvingSymlinksInPath().path
        guard canonicalSource == canonicalExpected else {
            throw MCPServerError.operationFailed("Docker backend effective workspace mount source is invalid")
        }
    }

    private func cleanupOwnedOrphans(shouldCancel: (() -> Bool)?) throws {
        let listed = try runDockerChecked(
            arguments: [
                "ps", "-a",
                "--filter", "label=\(Self.ownerLabelKey)=\(Self.ownerLabelValue)",
                "--filter", "label=\(Self.backendLabelKey)=\(Self.backendID)",
                "--filter", "label=\(Self.workspaceLabelKey)=\(workspaceAuthorityID)",
                "--format", "{{.ID}}",
            ],
            timeoutSeconds: configuration.startupTimeoutSeconds,
            operation: "docker orphan discovery",
            shouldCancel: shouldCancel
        )
        for raw in listed.stdout.components(separatedBy: .newlines) {
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard id.range(of: Self.containerIDPattern, options: .regularExpression) != nil else { continue }
            if isOwnedContainer(id: id, shouldCancel: shouldCancel) {
                _ = try runDockerChecked(
                    arguments: ["rm", "-f", id],
                    timeoutSeconds: configuration.startupTimeoutSeconds,
                    operation: "docker orphan cleanup",
                    shouldCancel: shouldCancel
                )
            }
        }
    }

    private func isOwnedContainer(id: String, shouldCancel: (() -> Bool)?) -> Bool {
        do {
            let result = try runDockerChecked(
                arguments: ["inspect", "--format", "{{json .Config.Labels}}", id],
                timeoutSeconds: configuration.startupTimeoutSeconds,
                operation: "docker ownership inspect",
                shouldCancel: shouldCancel
            )
            guard let data = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
                  let labels = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  labelEquals(labels, key: Self.ownerLabelKey, expected: Self.ownerLabelValue),
                  labelEquals(labels, key: Self.backendLabelKey, expected: Self.backendID),
                  labelEquals(labels, key: Self.workspaceLabelKey, expected: workspaceAuthorityID),
                  let lease = labels[Self.leaseLabelKey] as? String,
                  lease.range(of: "^[0-9a-f]{24}$", options: .regularExpression) != nil else {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    private func removeCurrentContainerBestEffort(ignoreDisposed: Bool = false) {
        containerLock.lock()
        defer { containerLock.unlock() }
        if !ignoreDisposed, isDisposed { return }
        removeCurrentContainerLockedBestEffort()
    }

    private func removeCurrentContainerLockedBestEffort() {
        let id = containerID
        containerID = nil
        leaseID = nil
        containerCreatedAt = nil
        lastActivityAt = nil
        if let id {
            removeOwnedContainerBestEffort(id: id, shouldCancel: nil)
        }
    }

    private func removeOwnedContainerBestEffort(id: String, shouldCancel: (() -> Bool)?) {
        guard isOwnedContainer(id: id, shouldCancel: shouldCancel) else { return }
        _ = try? docker.run(
            arguments: ["rm", "-f", id],
            environment: (try? dockerClientEnvironment()) ?? [:],
            timeoutSeconds: configuration.startupTimeoutSeconds,
            outputLimitBytes: Self.dockerControlOutputLimit,
            shouldCancel: shouldCancel
        )
    }

    private func sweepExpiredContainer() {
        if isDisposed { return }
        containerLock.lock()
        defer { containerLock.unlock() }
        if containerExpired() {
            pty.stopAll()
            removeCurrentContainerLockedBestEffort()
        }
    }

    private func containerExpired() -> Bool {
        guard containerID != nil, let created = containerCreatedAt, let last = lastActivityAt else { return false }
        let now = Date()
        return now.timeIntervalSince(last) >= Double(configuration.idleTTLSeconds) ||
            now.timeIntervalSince(created) >= Double(configuration.maxLifetimeSeconds)
    }

    private func revalidatedWorkspaceRoot() throws -> String {
        let resolved = try resolver.resolve("")
        guard resolver.contains(resolved),
              !resolved.path.contains(","),
              !resolved.path.contains("\n"),
              !resolved.path.contains("\r"),
              !resolved.path.utf8.contains(0) else {
            throw MCPServerError.operationFailed("Docker backend workspace mount source is not safely representable")
        }
        return resolved.path
    }

    private func containerWorkingDirectory(_ cwd: String) throws -> String {
        let resolved = try resolver.resolve(cwd)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw MCPServerError.notFound("No such working directory: \(cwd.isEmpty ? "." : cwd)")
        }
        let root = resolver.root.path
        if resolved.path == root { return Self.workspaceDestination }
        guard resolved.path.hasPrefix(root + "/") else {
            throw MCPServerError.invalidPath("Refused: path is outside the shared directory")
        }
        let relative = String(resolved.path.dropFirst(root.count + 1))
        return Self.workspaceDestination + "/" + relative
    }

    private func buildContainerEnvironment(_ overrides: [String: String]) throws -> [String: String] {
        if let reserved = overrides.keys.first(where: { key in
            Self.dockerControlEnvironmentNames.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame })
        }) {
            throw MCPServerError.invalidArguments("Environment override is reserved by the Docker execution backend: \(reserved)")
        }
        var environment = try environmentAuthority.buildIsolated(overrides: overrides)
        for name in Self.dockerControlEnvironmentNames {
            environment.removeValue(forKey: name)
        }
        return environment
    }

    private func dockerClientEnvironment(_ overrides: [String: String] = [:]) throws -> [String: String] {
        try dockerClientEnvironmentAuthority.build(overrides: overrides)
    }

    private func runDockerChecked(
        arguments: [String],
        timeoutSeconds: Int,
        operation: String,
        shouldCancel: (() -> Bool)?
    ) throws -> ProcessResult {
        let result: ProcessResult
        do {
            result = try docker.run(
                arguments: arguments,
                environment: try dockerClientEnvironment(),
                timeoutSeconds: timeoutSeconds,
                outputLimitBytes: Self.dockerControlOutputLimit,
                shouldCancel: shouldCancel
            )
        } catch {
            setHealth(ExecutionBackendHealth(available: true, state: "degraded", detail: "\(operation) unavailable"))
            throw MCPServerError.operationFailed("\(operation) unavailable: \(error.localizedDescription)")
        }

        if result.cancelled {
            throw MCPServerError.operationFailed("\(operation) cancelled")
        }
        if result.timedOut {
            setHealth(ExecutionBackendHealth(available: true, state: "degraded", detail: "\(operation) timed out"))
            throw MCPServerError.operationFailed("\(operation) timed out")
        }
        guard result.exitCode == 0 else {
            setHealth(ExecutionBackendHealth(available: true, state: "degraded", detail: "\(operation) failed"))
            let text = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw MCPServerError.operationFailed("\(operation) failed: \(String(text.prefix(1000)))")
        }
        return result
    }

    private func appendContainerEnvironmentArguments(_ arguments: inout [String], environment: [String: String]) {
        for name in environment.keys.sorted() {
            arguments.append("--env")
            arguments.append(name)
        }
    }

    private func requireLabel(_ labels: [String: Any], key: String, expected: String) throws {
        guard labelEquals(labels, key: key, expected: expected) else {
            throw MCPServerError.operationFailed("Docker backend ownership label mismatch: \(key)")
        }
    }

    private func labelEquals(_ labels: [String: Any], key: String, expected: String) -> Bool {
        (labels[key] as? String) == expected
    }

    private func touch() {
        containerLock.lock()
        lastActivityAt = Date()
        containerLock.unlock()
    }

    private func setHealth(_ value: ExecutionBackendHealth) {
        healthLock.lock()
        if !disposed { backendHealth = value }
        healthLock.unlock()
    }

    private func throwIfDisposed() throws {
        if isDisposed {
            throw MCPServerError.operationFailed("Execution backend is disposed")
        }
    }

    private static func formatCPU(_ value: Double) -> String {
        var text = String(format: "%.3f", value)
        while text.contains(".") && text.last == "0" { text.removeLast() }
        if text.last == "." { text.removeLast() }
        return text
    }

    private func formatCPU(_ value: Double) -> String {
        Self.formatCPU(value)
    }

    private func randomHex(byteCount: Int) -> String {
        (0..<byteCount).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    private func integer(_ value: Any?) -> Int64 {
        (value as? NSNumber)?.int64Value ?? 0
    }

    private func bool(_ value: Any?) -> Bool {
        (value as? NSNumber)?.boolValue ?? (value as? Bool ?? false)
    }
}
