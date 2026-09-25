import Foundation
import CryptoKit

enum FileMCPPolicyProfiles {
    static let restricted = "restricted"
    static let workspaceAuto = "workspace-auto"
    static let custom = "custom"
    static let legacyCommandCompatible = "legacy-command-compatible"

    static func isKnown(_ value: String) -> Bool {
        [restricted, workspaceAuto, custom, legacyCommandCompatible].contains(value)
    }

    static func isUserSelectable(_ value: String) -> Bool {
        [restricted, workspaceAuto, custom].contains(value)
    }
}

struct LocalPolicyConfiguration {
    var profile: String = FileMCPPolicyProfiles.restricted
    var customMaxRisk: String = "low"
    var customAllowedEffects: [String] = ["read", "metadata"]
    var customAllowNetworkOpenWorld = false
    var customAllowShell = false

    static func fromLegacy(enableCommands: Bool) -> LocalPolicyConfiguration {
        LocalPolicyConfiguration(
            profile: enableCommands ? FileMCPPolicyProfiles.legacyCommandCompatible : FileMCPPolicyProfiles.restricted
        )
    }

    func normalized() throws -> LocalPolicyConfiguration {
        let normalizedProfile = profile.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard FileMCPPolicyProfiles.isKnown(normalizedProfile) else {
            throw ToolCatalogError.invalid("Unsupported policy profile: \(profile)")
        }
        let normalizedRisk = customMaxRisk.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["low", "medium", "high"].contains(normalizedRisk) else {
            throw ToolCatalogError.invalid("Unsupported custom policy risk: \(customMaxRisk)")
        }
        let validEffects: Set<String> = ["read", "write", "delete", "execute", "external", "metadata"]
        let effects = Array(Set(customAllowedEffects
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty })).sorted()
        guard effects.allSatisfy({ validEffects.contains($0) }) else {
            throw ToolCatalogError.invalid("Custom policy contains an unsupported effect")
        }
        return LocalPolicyConfiguration(
            profile: normalizedProfile,
            customMaxRisk: normalizedRisk,
            customAllowedEffects: effects,
            customAllowNetworkOpenWorld: customAllowNetworkOpenWorld,
            customAllowShell: customAllowShell
        )
    }
}

struct PolicySnapshot: Equatable {
    let generation: UInt64
    let hash: String
}

final class ServerPolicy {
    private struct State {
        let generation: UInt64
        let hash: String
        let configuration: LocalPolicyConfiguration
    }

    private let lock = NSLock()
    private var state: State

    init(configuration: LocalPolicyConfiguration) throws {
        let normalized = try configuration.normalized()
        state = State(generation: 1, hash: try Self.computeHash(normalized), configuration: normalized)
    }

    static func fromLegacy(enableCommands: Bool) throws -> ServerPolicy {
        try ServerPolicy(configuration: .fromLegacy(enableCommands: enableCommands))
    }

    var profile: String {
        lock.lock(); defer { lock.unlock() }
        return state.configuration.profile
    }

    var generation: UInt64 {
        lock.lock(); defer { lock.unlock() }
        return state.generation
    }

    var hash: String {
        lock.lock(); defer { lock.unlock() }
        return state.hash
    }

    var legacyUnsafeGitCompatibility: Bool {
        lock.lock(); defer { lock.unlock() }
        return state.configuration.profile == FileMCPPolicyProfiles.legacyCommandCompatible
    }

    func capture() -> PolicySnapshot {
        lock.lock(); defer { lock.unlock() }
        return PolicySnapshot(generation: state.generation, hash: state.hash)
    }

    func update(_ configuration: LocalPolicyConfiguration) throws {
        let normalized = try configuration.normalized()
        let nextHash = try Self.computeHash(normalized)
        lock.lock()
        defer { lock.unlock() }
        guard nextHash != state.hash else { return }
        state = State(generation: state.generation &+ 1, hash: nextHash, configuration: normalized)
    }

    func isAllowed(_ toolName: String) -> Bool {
        guard let metadata = try? CanonicalToolCatalog.shared.toolPolicyMetadata(named: toolName) else { return false }
        lock.lock(); defer { lock.unlock() }
        return Self.isAllowed(state.configuration, metadata: metadata)
    }

    func filterDefinitions(_ definitions: [[String: Any]]) throws -> [[String: Any]] {
        try definitions.compactMap { definition in
            guard let name = definition["name"] as? String else {
                throw ToolCatalogError.invalid("Invalid tool definition while applying policy")
            }
            return isAllowed(name) ? definition : nil
        }
    }

    func authorize(_ toolName: String, prepared: PolicySnapshot? = nil) throws {
        let metadata = try CanonicalToolCatalog.shared.toolPolicyMetadata(named: toolName)
        lock.lock()
        defer { lock.unlock() }
        if let prepared,
           prepared.generation != state.generation || prepared.hash != state.hash {
            throw ToolCatalogError.invalid("Prepared operation is stale because local policy changed")
        }
        guard Self.isAllowed(state.configuration, metadata: metadata) else {
            throw ToolCatalogError.invalid("Tool is denied by active local policy: \(toolName)")
        }
    }

    func metadata() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        return [
            "profile": state.configuration.profile,
            "generation": NSNumber(value: state.generation),
            "hash": state.hash,
        ]
    }

    private static func isAllowed(_ configuration: LocalPolicyConfiguration, metadata: ToolPolicyMetadata) -> Bool {
        switch configuration.profile {
        case FileMCPPolicyProfiles.restricted:
            return !metadata.capabilities.contains("process.shell") &&
                !metadata.capabilities.contains("process.exec")
        case FileMCPPolicyProfiles.legacyCommandCompatible:
            return true
        case FileMCPPolicyProfiles.workspaceAuto:
            return !metadata.capabilities.contains("process.shell")
                && !metadata.capabilities.contains("network.open_world")
                && metadata.effect != "external"
        case FileMCPPolicyProfiles.custom:
            guard riskRank(metadata.risk) <= riskRank(configuration.customMaxRisk) else { return false }
            guard configuration.customAllowedEffects.contains(metadata.effect) else { return false }
            if !configuration.customAllowNetworkOpenWorld && metadata.capabilities.contains("network.open_world") { return false }
            if !configuration.customAllowShell && metadata.capabilities.contains("process.shell") { return false }
            return true
        default:
            return false
        }
    }

    private static func riskRank(_ value: String) -> Int {
        switch value {
        case "low": return 0
        case "medium": return 1
        case "high": return 2
        default: return Int.max
        }
    }

    private static func computeHash(_ configuration: LocalPolicyConfiguration) throws -> String {
        let canonical = [
            configuration.profile,
            configuration.customMaxRisk,
            configuration.customAllowedEffects.joined(separator: ","),
            configuration.customAllowNetworkOpenWorld ? "true" : "false",
            configuration.customAllowShell ? "true" : "false",
        ].joined(separator: "\n")
        return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
