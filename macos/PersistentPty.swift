import Foundation
import Darwin

struct PersistentPtyOptions {
    var maxSessions = 8
    var maxRingBytes = 1 * 1024 * 1024
    var spillChunkBytes = 128 * 1024
    var defaultIdleTTL: TimeInterval = 10 * 60
    var maxIdleTTL: TimeInterval = 60 * 60
    var defaultMaxLifetime: TimeInterval = 60 * 60
    var maxLifetime: TimeInterval = 4 * 60 * 60
    var spillTTL: TimeInterval = 15 * 60

    func validate() throws {
        guard (1...32).contains(maxSessions) else {
            throw MCPServerError.invalidArguments("PTY maxSessions must be 1..32")
        }
        guard maxRingBytes >= 64 * 1024, maxRingBytes <= 8 * 1024 * 1024 else {
            throw MCPServerError.invalidArguments("PTY maxRingBytes must be 65536..8388608")
        }
        guard spillChunkBytes >= 16 * 1024, spillChunkBytes <= maxRingBytes else {
            throw MCPServerError.invalidArguments("PTY spillChunkBytes must be 16384..maxRingBytes")
        }
        guard defaultIdleTTL > 0, maxIdleTTL >= defaultIdleTTL,
              defaultMaxLifetime > 0, maxLifetime >= defaultMaxLifetime,
              spillTTL > 0 else {
            throw MCPServerError.invalidArguments("PTY TTL configuration is invalid")
        }
    }
}

private final class PosixPtyHost {
    let processID: pid_t
    let processGroupID: pid_t
    private let readFD: Int32
    private let writeFD: Int32
    private let stateLock = NSLock()
    private let exitGroup = DispatchGroup()
    private var running = true
    private var exitCodeValue: Int32?
    private var closed = false

    private init(processID: pid_t, masterReadFD: Int32, masterWriteFD: Int32) {
        self.processID = processID
        self.processGroupID = processID
        self.readFD = masterReadFD
        self.writeFD = masterWriteFD
        exitGroup.enter()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var status: Int32 = 0
            while true {
                let result = waitpid(processID, &status, 0)
                if result == processID || (result == -1 && errno == ECHILD) {
                    break
                }
                if result == -1 && errno != EINTR {
                    break
                }
            }
            self.stateLock.lock()
            self.running = false
            self.exitCodeValue = Self.decodeExitCode(status)
            self.stateLock.unlock()
            self.exitGroup.leave()
        }
    }

    @available(macOS, introduced: 10.15, obsoleted: 26.0)
    private static func addLegacySpawnChdir(
        _ actions: UnsafeMutablePointer<posix_spawn_file_actions_t?>,
        _ path: UnsafePointer<CChar>
    ) -> Int32 {
        posix_spawn_file_actions_addchdir_np(actions, path)
    }

    static func start(
        executable: String,
        arguments: [String],
        cwd: String,
        environment: [String: String],
        columns: Int,
        rows: Int
    ) throws -> PosixPtyHost {
        try validatePOSIXStrings(
            executable: executable,
            arguments: arguments,
            cwd: cwd,
            environment: environment
        )

        guard let executableCString = strdup(executable),
              let cwdCString = strdup(cwd) else {
            throw MCPServerError.operationFailed("Could not allocate PTY launch strings")
        }
        defer {
            free(executableCString)
            free(cwdCString)
        }

        let argumentStrings = [executable] + arguments
        let argvPointer = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(
            capacity: argumentStrings.count + 1
        )
        argvPointer.initialize(repeating: nil, count: argumentStrings.count + 1)
        var allocatedArgCount = 0
        do {
            for (index, value) in argumentStrings.enumerated() {
                guard let pointer = strdup(value) else {
                    throw MCPServerError.operationFailed("Could not allocate PTY argv")
                }
                argvPointer[index] = pointer
                allocatedArgCount += 1
            }
        } catch {
            for index in 0..<allocatedArgCount {
                if let pointer = argvPointer[index] { free(pointer) }
            }
            argvPointer.deinitialize(count: argumentStrings.count + 1)
            argvPointer.deallocate()
            throw error
        }
        defer {
            for index in 0..<allocatedArgCount {
                if let pointer = argvPointer[index] { free(pointer) }
            }
            argvPointer.deinitialize(count: argumentStrings.count + 1)
            argvPointer.deallocate()
        }

        let environmentStrings = environment
            .map { "\($0.key)=\($0.value)" }
            .sorted()
        let envPointer = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(
            capacity: environmentStrings.count + 1
        )
        envPointer.initialize(repeating: nil, count: environmentStrings.count + 1)
        var allocatedEnvCount = 0
        do {
            for (index, value) in environmentStrings.enumerated() {
                guard let pointer = strdup(value) else {
                    throw MCPServerError.operationFailed("Could not allocate PTY environment")
                }
                envPointer[index] = pointer
                allocatedEnvCount += 1
            }
        } catch {
            for index in 0..<allocatedEnvCount {
                if let pointer = envPointer[index] { free(pointer) }
            }
            envPointer.deinitialize(count: environmentStrings.count + 1)
            envPointer.deallocate()
            throw error
        }
        defer {
            for index in 0..<allocatedEnvCount {
                if let pointer = envPointer[index] { free(pointer) }
            }
            envPointer.deinitialize(count: environmentStrings.count + 1)
            envPointer.deallocate()
        }

        var masterFD: Int32 = -1
        var size = winsize(
            ws_row: UInt16(rows),
            ws_col: UInt16(columns),
            ws_xpixel: 0,
            ws_ypixel: 0
        )

        var slaveFD: Int32 = -1
        guard openpty(&masterFD, &slaveFD, nil, nil, &size) == 0 else {
            throw MCPServerError.operationFailed(
                "Could not allocate POSIX PTY: \(String(cString: strerror(errno)))"
            )
        }

        var fileActions: posix_spawn_file_actions_t?
        var spawnAttributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&fileActions) == 0 else {
            Darwin.close(masterFD)
            Darwin.close(slaveFD)
            throw MCPServerError.operationFailed("Could not initialize PTY spawn file actions")
        }
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        guard posix_spawnattr_init(&spawnAttributes) == 0 else {
            Darwin.close(masterFD)
            Darwin.close(slaveFD)
            throw MCPServerError.operationFailed("Could not initialize PTY spawn attributes")
        }
        defer { posix_spawnattr_destroy(&spawnAttributes) }

        func requireSpawnAction(_ code: Int32, _ message: String) throws {
            guard code == 0 else {
                throw MCPServerError.operationFailed("\(message): \(String(cString: strerror(code)))")
            }
        }

        do {
            let chdirResult: Int32
            if #available(macOS 26.0, *) {
                chdirResult = posix_spawn_file_actions_addchdir(&fileActions, cwdCString)
            } else {
                chdirResult = Self.addLegacySpawnChdir(&fileActions, cwdCString)
            }
            try requireSpawnAction(
                chdirResult,
                "Could not configure PTY working directory"
            )
            try requireSpawnAction(posix_spawn_file_actions_adddup2(&fileActions, slaveFD, STDIN_FILENO), "Could not bind PTY stdin")
            try requireSpawnAction(posix_spawn_file_actions_adddup2(&fileActions, slaveFD, STDOUT_FILENO), "Could not bind PTY stdout")
            try requireSpawnAction(posix_spawn_file_actions_adddup2(&fileActions, slaveFD, STDERR_FILENO), "Could not bind PTY stderr")
            try requireSpawnAction(posix_spawn_file_actions_addclose(&fileActions, masterFD), "Could not isolate PTY master")
            if slaveFD > STDERR_FILENO {
                try requireSpawnAction(posix_spawn_file_actions_addclose(&fileActions, slaveFD), "Could not close PTY slave after dup")
            }

            try requireSpawnAction(posix_spawnattr_setpgroup(&spawnAttributes, 0), "Could not configure PTY process group")
            try requireSpawnAction(
                posix_spawnattr_setflags(&spawnAttributes, Int16(POSIX_SPAWN_SETPGROUP)),
                "Could not enable PTY process-group creation"
            )
        } catch {
            Darwin.close(masterFD)
            Darwin.close(slaveFD)
            throw error
        }

        var pid: pid_t = 0
        let spawnResult = posix_spawn(
            &pid,
            executableCString,
            &fileActions,
            &spawnAttributes,
            argvPointer,
            envPointer
        )
        Darwin.close(slaveFD)
        guard spawnResult == 0, pid > 0 else {
            Darwin.close(masterFD)
            throw MCPServerError.operationFailed(
                "Could not launch POSIX PTY process: \(String(cString: strerror(spawnResult)))"
            )
        }

        let writeFD = dup(masterFD)
        guard writeFD >= 0 else {
            _ = kill(pid, SIGKILL)
            Darwin.close(masterFD)
            var status: Int32 = 0
            _ = waitpid(pid, &status, 0)
            throw MCPServerError.operationFailed(
                "Could not duplicate POSIX PTY master descriptor: \(String(cString: strerror(errno)))"
            )
        }

        _ = fcntl(masterFD, F_SETFD, FD_CLOEXEC)
        _ = fcntl(writeFD, F_SETFD, FD_CLOEXEC)
        return PosixPtyHost(processID: pid, masterReadFD: masterFD, masterWriteFD: writeFD)
    }

    var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return running
    }

    func read(upToCount count: Int) throws -> Data {
        guard count > 0 else { return Data() }
        var buffer = [UInt8](repeating: 0, count: count)
        while true {
            let result = buffer.withUnsafeMutableBytes { raw -> Int in
                Darwin.read(readFD, raw.baseAddress, count)
            }
            if result > 0 { return Data(buffer.prefix(result)) }
            if result == 0 { return Data() }
            if errno == EINTR { continue }
            if errno == EIO {
                // PTY masters can report EIO around slave lifecycle transitions.
                // Keep the reader alive while the owned child is still running.
                if isRunning {
                    usleep(10_000)
                    continue
                }
                return Data()
            }
            throw MCPServerError.operationFailed(
                "Could not read POSIX PTY master: \(String(cString: strerror(errno)))"
            )
        }
    }

    func write(_ data: Data) throws {
        if data.isEmpty { return }
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < raw.count {
                let result = Darwin.write(writeFD, base.advanced(by: offset), raw.count - offset)
                if result > 0 {
                    offset += result
                    continue
                }
                if result < 0 && errno == EINTR { continue }
                throw MCPServerError.operationFailed(
                    "Could not write POSIX PTY master: \(String(cString: strerror(errno)))"
                )
            }
        }
    }

    func waitForExit() -> Int32 {
        exitGroup.wait()
        stateLock.lock()
        defer { stateLock.unlock() }
        return exitCodeValue ?? -1
    }

    func resize(columns: Int, rows: Int) throws {
        guard isRunning else {
            throw MCPServerError.operationFailed("PTY session is not running")
        }
        var size = winsize(
            ws_row: UInt16(rows),
            ws_col: UInt16(columns),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        let result = ioctl(readFD, UInt(TIOCSWINSZ), &size)
        guard result == 0 else {
            throw MCPServerError.operationFailed(
                "Could not resize POSIX PTY: \(String(cString: strerror(errno)))"
            )
        }
    }

    func signal(_ signal: String) throws {
        guard isRunning else {
            throw MCPServerError.operationFailed("PTY session is not running")
        }
        switch signal {
        case "ctrl_c":
            try signalProcessGroup(SIGINT, label: "Ctrl-C")
        case "terminate":
            try signalProcessGroup(SIGTERM, label: "terminate")
        default:
            throw MCPServerError.invalidArguments("PTY signal must be ctrl_c or terminate")
        }
    }

    private func signalProcessGroup(_ signalNumber: Int32, label: String) throws {
        guard ownsProcessGroup() else {
            throw MCPServerError.operationFailed("Refused PTY signal: process-group ownership is no longer proven")
        }
        if killpg(processGroupID, signalNumber) != 0 && errno != ESRCH {
            throw MCPServerError.operationFailed(
                "Could not send \(label) to POSIX PTY process group: \(String(cString: strerror(errno)))"
            )
        }
    }

    func stop() {
        guard isRunning else { return }

        // Prove ownership while the original session leader is still alive.
        // This avoids sending process-group signals based on a recycled PID alone.
        let owned = ownsProcessGroup()
        if owned {
            _ = killpg(processGroupID, SIGTERM)
            let deadline = Date().addingTimeInterval(1.0)
            while Date() < deadline {
                if !isRunning { break }
                usleep(20_000)
            }
            // Ownership was proven at the start of this bounded stop window.
            // If descendants still keep the group alive, finish cleanup with SIGKILL.
            if killpg(processGroupID, 0) == 0 {
                _ = killpg(processGroupID, SIGKILL)
            }
        } else {
            _ = kill(processID, SIGTERM)
        }

        _ = exitGroup.wait(timeout: .now() + 2)
    }

    func close() {
        stateLock.lock()
        if closed {
            stateLock.unlock()
            return
        }
        closed = true
        stateLock.unlock()
        _ = Darwin.close(readFD)
        _ = Darwin.close(writeFD)
    }

    deinit {
        stop()
        close()
    }

    private func ownsProcessGroup() -> Bool {
        guard isRunning else { return false }
        errno = 0
        let group = getpgid(processID)
        return group == processGroupID
    }

    private static func validatePOSIXStrings(
        executable: String,
        arguments: [String],
        cwd: String,
        environment: [String: String]
    ) throws {
        guard !executable.isEmpty, !executable.utf8.contains(0) else {
            throw MCPServerError.invalidArguments("PTY executable must be a non-empty string without NUL bytes")
        }
        guard arguments.count <= 256, arguments.allSatisfy({ !$0.utf8.contains(0) }) else {
            throw MCPServerError.invalidArguments("PTY arguments are invalid or exceed 256 entries")
        }
        guard !cwd.utf8.contains(0) else {
            throw MCPServerError.invalidArguments("PTY working directory contains a NUL byte")
        }
        for (key, value) in environment {
            guard !key.isEmpty, !key.contains("="), !key.utf8.contains(0), !value.utf8.contains(0) else {
                throw MCPServerError.invalidArguments("PTY environment contains an invalid POSIX variable")
            }
        }
    }

    private static func decodeExitCode(_ status: Int32) -> Int32 {
        if (status & 0x7f) == 0 {
            return (status >> 8) & 0xff
        }
        let signal = status & 0x7f
        return signal == 0 ? status : 128 + signal
    }
}

final class PersistentPtyService {
    private final class Session {
        let id: String
        let host: PosixPtyHost
        let created: Date
        var lastActivity: Date
        let idleTTL: TimeInterval
        let maxLifetime: TimeInterval
        let options: PersistentPtyOptions
        let spillOutput: Bool
        let workspaceAuthorityID: String
        let artifactFactory: () throws -> ArtifactContentStore

        private let lock = NSLock()
        private let readerGroup = DispatchGroup()
        private var ring = Data()
        private var spillAccumulator = Data()
        private var spillRefs: [String] = []
        private var baseOffset: Int64 = 0
        private var endOffset: Int64 = 0
        private var exitCode: Int32?
        private var stateValue = "running"
        private var disposed = false

        init(
            id: String,
            host: PosixPtyHost,
            created: Date,
            idleTTL: TimeInterval,
            maxLifetime: TimeInterval,
            options: PersistentPtyOptions,
            spillOutput: Bool,
            workspaceAuthorityID: String,
            artifactFactory: @escaping () throws -> ArtifactContentStore
        ) {
            self.id = id
            self.host = host
            self.created = created
            self.lastActivity = created
            self.idleTTL = idleTTL
            self.maxLifetime = maxLifetime
            self.options = options
            self.spillOutput = spillOutput
            self.workspaceAuthorityID = workspaceAuthorityID
            self.artifactFactory = artifactFactory
        }

        var state: String {
            lock.lock()
            defer { lock.unlock() }
            return stateValue
        }

        var terminal: Bool { state != "running" }

        var earliestOffset: Int64 {
            lock.lock()
            defer { lock.unlock() }
            return baseOffset
        }

        func touch() {
            lock.lock()
            lastActivity = Date()
            lock.unlock()
        }

        func snapshotTimes() -> (lastActivity: Date, created: Date) {
            lock.lock()
            defer { lock.unlock() }
            return (lastActivity, created)
        }

        func start() {
            readerGroup.enter()
            DispatchQueue.global(qos: .utility).async { [weak self] in
                defer { self?.readerGroup.leave() }
                self?.readLoop()
            }
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.waitLoop()
            }
        }

        private func readLoop() {
            while true {
                do {
                    let chunk = try host.read(upToCount: 16 * 1024)
                    if chunk.isEmpty { break }
                    append(chunk)
                } catch {
                    break
                }
            }
        }

        private func waitLoop() {
            let code = host.waitForExit()
            _ = readerGroup.wait(timeout: .now() + 1)
            lock.lock()
            exitCode = code
            if stateValue == "running" {
                stateValue = "exited"
            }
            lastActivity = Date()
            lock.unlock()
            flushSpill()
        }

        private func append(_ data: Data) {
            var spill: Data?
            lock.lock()
            lastActivity = Date()
            ring.append(data)
            endOffset += Int64(data.count)
            let overflow = max(0, ring.count - options.maxRingBytes)
            if overflow > 0 {
                if spillOutput {
                    spillAccumulator.append(ring.prefix(overflow))
                }
                ring.removeFirst(overflow)
                baseOffset += Int64(overflow)
                if spillOutput && spillAccumulator.count >= options.spillChunkBytes {
                    spill = spillAccumulator
                    spillAccumulator.removeAll(keepingCapacity: true)
                }
            }
            lock.unlock()

            if let spill {
                spillData(spill)
            }
        }

        private func spillData(_ data: Data) {
            do {
                let descriptor = try artifactFactory().put(
                    data: data,
                    workspaceAuthorityID: workspaceAuthorityID,
                    contentClass: ArtifactContentClasses.ptyOutput,
                    mediaType: "application/octet-stream",
                    ttl: options.spillTTL,
                    leaseID: id,
                    leaseTTL: options.spillTTL
                )
                lock.lock()
                spillRefs.append(descriptor.contentRef)
                lock.unlock()
            } catch {
                // Spill is best-effort. The bounded in-memory ring remains authoritative.
            }
        }

        func read(requestedOffset: Int64, maxBytes: Int) throws -> [String: Any] {
            lock.lock()
            defer { lock.unlock() }
            lastActivity = Date()
            guard requestedOffset <= endOffset else {
                throw MCPServerError.invalidArguments("PTY cursor is beyond current output")
            }
            let evicted = requestedOffset < baseOffset
            let effective = max(requestedOffset, baseOffset)
            let relativeIndex = Int(effective - baseOffset)
            guard relativeIndex >= 0, relativeIndex <= ring.count else {
                throw MCPServerError.operationFailed("PTY ring cursor state is inconsistent")
            }
            let count = min(maxBytes, ring.count - relativeIndex)
            let bytes: Data
            if count > 0 {
                let start = ring.index(ring.startIndex, offsetBy: relativeIndex)
                let end = ring.index(start, offsetBy: count)
                bytes = Data(ring[start..<end])
            } else {
                bytes = Data()
            }
            let next = effective + Int64(count)
            let exit: Any = exitCode.map { Int($0) } ?? NSNull()
            return [
                "session_id": id,
                "state": stateValue,
                "start_cursor": String(effective),
                "next_cursor": String(next),
                "earliest_cursor": String(baseOffset),
                "end_cursor": String(endOffset),
                "cursor_evicted": evicted,
                "data_base64": bytes.base64EncodedString(),
                "text": String(decoding: bytes, as: UTF8.self),
                "exit_code": exit,
                "spill_pending": false,
                "spill_refs": spillRefs,
                "grants_authority": false,
            ]
        }

        func write(_ data: Data) throws {
            guard !terminal else {
                throw MCPServerError.operationFailed("PTY session is not running")
            }
            touch()
            try host.write(data)
        }

        func resize(columns: Int, rows: Int) throws {
            guard !terminal else {
                throw MCPServerError.operationFailed("PTY session is not running")
            }
            touch()
            try host.resize(columns: columns, rows: rows)
        }

        func signal(_ signal: String) throws {
            guard !terminal else {
                throw MCPServerError.operationFailed("PTY session is not running")
            }
            touch()
            try host.signal(signal)
        }

        func stop(state: String) {
            var shouldStop = false
            lock.lock()
            if stateValue == "running" {
                stateValue = state
                shouldStop = true
            }
            lastActivity = Date()
            lock.unlock()

            if shouldStop {
                host.stop()
            }
            _ = readerGroup.wait(timeout: .now() + 1)
            flushSpill()
            deleteSpills()
        }

        func metadata() -> [String: Any] {
            lock.lock()
            defer { lock.unlock() }
            let exit: Any = exitCode.map { Int($0) } ?? NSNull()
            return [
                "session_id": id,
                "pid": Int(host.processID),
                "state": stateValue,
                "created_epoch_ms": Int64(created.timeIntervalSince1970 * 1000),
                "last_activity_epoch_ms": Int64(lastActivity.timeIntervalSince1970 * 1000),
                "earliest_cursor": String(baseOffset),
                "end_cursor": String(endOffset),
                "exit_code": exit,
                "spill_ref_count": spillRefs.count,
                "actual_pty": true,
                "restart_resume_supported": false,
                "grants_authority": false,
            ]
        }

        func dispose() {
            lock.lock()
            if disposed {
                lock.unlock()
                return
            }
            disposed = true
            lock.unlock()
            stop(state: "disposed")
            host.close()
        }

        private func flushSpill() {
            var tail: Data?
            lock.lock()
            if spillOutput && !spillAccumulator.isEmpty {
                tail = spillAccumulator
                spillAccumulator.removeAll(keepingCapacity: true)
            }
            lock.unlock()
            if let tail {
                spillData(tail)
            }
        }

        private func deleteSpills() {
            lock.lock()
            let refs = spillRefs
            spillRefs.removeAll()
            lock.unlock()
            for contentRef in refs {
                do {
                    _ = try artifactFactory().delete(
                        contentRef: contentRef,
                        workspaceAuthorityID: workspaceAuthorityID,
                        contentClassAllowed: ArtifactContentClasses.isKnown
                    )
                } catch {
                    // Cleanup is best-effort; Artifact Store TTL remains a final safety net.
                }
            }
        }
    }

    private let resolver: SafePathResolver
    private let environmentAuthority: ExecProcessEnvironmentAuthority
    private let artifactFactory: () throws -> ArtifactContentStore
    private let options: PersistentPtyOptions
    private let workspaceAuthorityID: String
    private let lock = NSLock()
    private var sessions: [String: Session] = [:]
    private var disposed = false
    private let sweepTimer: DispatchSourceTimer

    init(
        resolver: SafePathResolver,
        environmentAuthority: ExecProcessEnvironmentAuthority,
        artifactFactory: @escaping () throws -> ArtifactContentStore,
        options: PersistentPtyOptions = PersistentPtyOptions()
    ) throws {
        try options.validate()
        self.resolver = resolver
        self.environmentAuthority = environmentAuthority
        self.artifactFactory = artifactFactory
        self.options = options
        self.workspaceAuthorityID = ArtifactContentStore.workspaceAuthorityID(resolver.root)

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        self.sweepTimer = timer
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            self?.sweep()
        }
        timer.resume()
    }

    deinit {
        sweepTimer.cancel()
        stopAll()
    }

    func start(
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
        sweep()

        guard !executable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !executable.utf8.contains(0) else {
            throw MCPServerError.invalidArguments("PTY executable must be a non-empty string without NUL bytes")
        }
        guard arguments.count <= 256, arguments.allSatisfy({ !$0.utf8.contains(0) }) else {
            throw MCPServerError.invalidArguments("PTY arguments are invalid or exceed 256 entries")
        }
        try Self.validateSize(columns: columns, rows: rows)

        let workdir = try resolver.resolve(cwd)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workdir.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw MCPServerError.notFound("No such PTY working directory: \(cwd.isEmpty ? "." : cwd)")
        }

        let idleTTL = try Self.resolveTTL(
            idleTTLSeconds,
            fallback: options.defaultIdleTTL,
            maximum: options.maxIdleTTL,
            name: "idle_ttl_seconds"
        )
        let maxLifetime = try Self.resolveTTL(
            maxLifetimeSeconds,
            fallback: options.defaultMaxLifetime,
            maximum: options.maxLifetime,
            name: "max_lifetime_seconds"
        )
        let environment = try environmentAuthority.build(overrides: environmentOverrides)

        lock.lock()
        let activeCount = sessions.values.filter { !$0.terminal }.count
        lock.unlock()
        guard activeCount < options.maxSessions else {
            throw MCPServerError.operationFailed("PTY session limit reached (\(options.maxSessions))")
        }

        let host = try PosixPtyHost.start(
            executable: executable,
            arguments: arguments,
            cwd: workdir.path,
            environment: environment,
            columns: columns,
            rows: rows
        )
        let id = "pty_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let now = Date()
        let session = Session(
            id: id,
            host: host,
            created: now,
            idleTTL: idleTTL,
            maxLifetime: maxLifetime,
            options: options,
            spillOutput: spillOutput,
            workspaceAuthorityID: workspaceAuthorityID,
            artifactFactory: artifactFactory
        )

        lock.lock()
        sessions[id] = session
        lock.unlock()
        session.start()

        return [
            "session_id": id,
            "pid": Int(host.processID),
            "state": "running",
            "columns": columns,
            "rows": rows,
            "idle_ttl_seconds": Int(idleTTL),
            "max_lifetime_seconds": Int(maxLifetime),
            "ring_limit_bytes": options.maxRingBytes,
            "spill_output": spillOutput,
            "actual_pty": true,
            "pty_backend": "macos-posix-openpty-spawn",
            "grants_authority": false,
        ]
    }

    func read(
        sessionID: String,
        cursor: String,
        maxBytes: Int,
        context: ToolExecutionContext?
    ) throws -> [String: Any] {
        guard (1...(256 * 1024)).contains(maxBytes) else {
            throw MCPServerError.invalidArguments("PTY max_bytes must be 1..262144")
        }
        if let context, !context.tryContinue() {
            throw MCPServerError.operationFailed("PTY read cancelled or budget exhausted")
        }
        let session = try getSession(sessionID)
        let requested = cursor.isEmpty ? session.earliestOffset : try Self.parseCursor(cursor)
        let result = try session.read(requestedOffset: requested, maxBytes: maxBytes)
        if let context, !context.tryOutputItem() {
            context.markTruncated("output_items")
        }
        return result
    }

    func write(sessionID: String, data: String) throws -> [String: Any] {
        guard data.count <= 64 * 1024 else {
            throw MCPServerError.invalidArguments("PTY write is limited to 65536 characters per call")
        }
        let session = try getSession(sessionID)
        let bytes = Data(data.utf8)
        try session.write(bytes)
        return [
            "session_id": sessionID,
            "written_bytes": bytes.count,
            "state": session.state,
            "grants_authority": false,
        ]
    }

    func resize(sessionID: String, columns: Int, rows: Int) throws -> [String: Any] {
        try Self.validateSize(columns: columns, rows: rows)
        let session = try getSession(sessionID)
        try session.resize(columns: columns, rows: rows)
        return [
            "session_id": sessionID,
            "columns": columns,
            "rows": rows,
            "state": session.state,
            "grants_authority": false,
        ]
    }

    func signal(sessionID: String, signal: String) throws -> [String: Any] {
        guard signal == "ctrl_c" || signal == "terminate" else {
            throw MCPServerError.invalidArguments("PTY signal must be ctrl_c or terminate")
        }
        let session = try getSession(sessionID)
        try session.signal(signal)
        return [
            "session_id": sessionID,
            "signal": signal,
            "state": session.state,
            "grants_authority": false,
        ]
    }

    func stop(sessionID: String) throws -> [String: Any] {
        let session = try getSession(sessionID)
        session.stop(state: "stopped")
        return session.metadata()
    }

    func list() -> [String: Any] {
        lock.lock()
        let snapshot = sessions.values.sorted { $0.created < $1.created }
        lock.unlock()
        return [
            "sessions": snapshot.map { $0.metadata() },
            "count": snapshot.count,
            "workspace_scoped": true,
            "restart_resume_supported": false,
            "grants_authority": false,
        ]
    }

    func stopAll() {
        lock.lock()
        let snapshot = Array(sessions.values)
        lock.unlock()
        for session in snapshot {
            session.stop(state: "server_stopped")
        }
    }

    func sweepNowForTests() {
        sweep()
    }

    private func getSession(_ id: String) throws -> Session {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, id.count <= 128 else {
            throw MCPServerError.invalidArguments("Invalid PTY session id")
        }
        lock.lock()
        let session = sessions[id]
        lock.unlock()
        guard let session else {
            throw MCPServerError.notFound("Unknown or expired PTY session")
        }
        session.touch()
        return session
    }

    private func sweep() {
        lock.lock()
        if disposed {
            lock.unlock()
            return
        }
        let snapshot = Array(sessions.values)
        lock.unlock()

        let now = Date()
        var expiredTerminalIDs: [String] = []
        for session in snapshot {
            let times = session.snapshotTimes()
            if session.terminal {
                if now.timeIntervalSince(times.lastActivity) > 120 {
                    expiredTerminalIDs.append(session.id)
                }
                continue
            }
            if now.timeIntervalSince(times.lastActivity) > session.idleTTL {
                session.stop(state: "idle_expired")
            } else if now.timeIntervalSince(times.created) > session.maxLifetime {
                session.stop(state: "lifetime_expired")
            }
        }

        if !expiredTerminalIDs.isEmpty {
            lock.lock()
            let removed = expiredTerminalIDs.compactMap { sessions.removeValue(forKey: $0) }
            lock.unlock()
            for session in removed {
                session.dispose()
            }
        }
    }

    private func throwIfDisposed() throws {
        lock.lock()
        let isDisposed = disposed
        lock.unlock()
        if isDisposed {
            throw MCPServerError.operationFailed("Persistent PTY service is disposed")
        }
    }

    private static func resolveTTL(
        _ seconds: Int,
        fallback: TimeInterval,
        maximum: TimeInterval,
        name: String
    ) throws -> TimeInterval {
        if seconds == 0 { return fallback }
        guard seconds >= 1, Double(seconds) <= maximum else {
            throw MCPServerError.invalidArguments("\(name) must be 1..\(Int(maximum))")
        }
        return TimeInterval(seconds)
    }

    private static func validateSize(columns: Int, rows: Int) throws {
        guard (1...500).contains(columns), (1...300).contains(rows) else {
            throw MCPServerError.invalidArguments("PTY size must be columns 1..500 and rows 1..300")
        }
    }

    private static func parseCursor(_ cursor: String) throws -> Int64 {
        guard let value = Int64(cursor), value >= 0 else {
            throw MCPServerError.invalidArguments("Invalid PTY cursor")
        }
        return value
    }
}
