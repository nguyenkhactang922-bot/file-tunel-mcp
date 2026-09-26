import Foundation
import CryptoKit

struct ToolPolicyMetadata {
    let name: String
    let risk: String
    let effect: String
    let capabilities: [String]
}

enum ToolCatalogError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case let .invalid(message): return message }
    }
}

final class CanonicalToolCatalog {
    private static let supportedSchemaVersion = 1
    private static let supportedCatalogVersion = "1.5.0"
    private static let supportedInstructionVersion = "1.0.0"
    private static let supportedRisks: Set<String> = ["low", "medium", "high"]
    private static let supportedEffects: Set<String> = ["read", "write", "delete", "execute", "external", "metadata"]
    private static let supportedHandlers: Set<String> = ["local_tools", "skills", "server"]
    private static let supportedAvailabilityKeys: Set<String> = ["requiresCommands", "requiresObservability"]

    static let shared: CanonicalToolCatalog = {
        do { return try CanonicalToolCatalog.load() }
        catch { fatalError("Canonical tool catalog integrity failure: \(error.localizedDescription)") }
    }()

    let catalogVersion: String
    let catalogHash: String
    let instructionVersion: String
    let instructionHash: String
    let modernProtocolVersion: String
    let legacyProtocolVersions: [String]
    let baseInstructions: String
    let observabilityInstructionsSuffix: String
    let correlationArgumentName: String
    private let correlationArgumentDefinitionValue: [String: Any]
    private let tools: [[String: Any]]

    private init(data: Data, root: [String: Any]) throws {
        guard let schemaVersion = root["schemaVersion"] as? NSNumber, schemaVersion.intValue == Self.supportedSchemaVersion else {
            throw ToolCatalogError.invalid("Unsupported canonical tool catalog schemaVersion")
        }
        catalogVersion = try Self.requiredString(root, "catalogVersion")
        guard catalogVersion == Self.supportedCatalogVersion else {
            throw ToolCatalogError.invalid("Unsupported canonical tool catalog catalogVersion: \(catalogVersion)")
        }
        instructionVersion = try Self.requiredString(root, "instructionVersion")
        guard instructionVersion == Self.supportedInstructionVersion else {
            throw ToolCatalogError.invalid("Unsupported canonical tool catalog instructionVersion: \(instructionVersion)")
        }
        let protocols = try Self.requiredObject(root, "protocolVersions")
        modernProtocolVersion = try Self.requiredString(protocols, "modern")
        legacyProtocolVersions = try Self.requiredStringArray(protocols, "legacy")
        let instructions = try Self.requiredObject(root, "instructions")
        baseInstructions = try Self.requiredString(instructions, "base")
        observabilityInstructionsSuffix = try Self.requiredString(instructions, "observabilitySuffix")
        let facades = try Self.requiredObject(root, "facades")
        let correlation = try Self.requiredObject(facades, "correlationArgument")
        correlationArgumentName = try Self.requiredString(correlation, "name")
        correlationArgumentDefinitionValue = try Self.requiredObject(correlation, "definition")
        guard let toolArray = root["tools"] as? [[String: Any]], !toolArray.isEmpty else {
            throw ToolCatalogError.invalid("Canonical tool catalog tools must be a non-empty array")
        }
        var seen = Set<String>()
        for item in toolArray {
            let name = try Self.requiredString(item, "name")
            guard seen.insert(name).inserted else { throw ToolCatalogError.invalid("Duplicate canonical tool name: \(name)") }
            let handler = try Self.requiredString(item, "handler")
            guard Self.supportedHandlers.contains(handler) else {
                throw ToolCatalogError.invalid("Unsupported canonical tool handler metadata for \(name): \(handler)")
            }
            let risk = try Self.requiredString(item, "risk")
            guard Self.supportedRisks.contains(risk) else {
                throw ToolCatalogError.invalid("Unsupported canonical tool risk metadata for \(name): \(risk)")
            }
            let effect = try Self.requiredString(item, "effect")
            guard Self.supportedEffects.contains(effect) else {
                throw ToolCatalogError.invalid("Unsupported canonical tool effect metadata for \(name): \(effect)")
            }
            let capabilities = try Self.requiredStringArray(item, "capabilities")
            guard !capabilities.isEmpty else {
                throw ToolCatalogError.invalid("Canonical tool capabilities must not be empty for \(name)")
            }
            let availability = try Self.requiredObject(item, "availability")
            for (key, value) in availability {
                guard Self.supportedAvailabilityKeys.contains(key), value is Bool else {
                    throw ToolCatalogError.invalid("Unsupported canonical tool availability metadata for \(name): \(key)")
                }
            }
            let definition = try Self.requiredObject(item, "definition")
            guard try Self.requiredString(definition, "name") == name else {
                throw ToolCatalogError.invalid("Canonical definition name mismatch for \(name)")
            }
            _ = try Self.requiredObject(definition, "inputSchema")
            _ = try Self.requiredObject(definition, "outputSchema")
            _ = try Self.requiredObject(definition, "annotations")
        }
        tools = toolArray
        catalogHash = Self.sha256Hex(try Self.normalizedCatalogData(data))
        instructionHash = Self.sha256Hex(Data(Self.composeInstructions(baseInstructions, observabilityInstructionsSuffix).utf8))
    }

    func instructions(includeObservability: Bool) -> String {
        includeObservability ? Self.composeInstructions(baseInstructions, observabilityInstructionsSuffix) : baseInstructions
    }

    func metadata(buildIdentity: String) -> [String: Any] {
        [
            "catalogVersion": catalogVersion,
            "catalogHash": catalogHash,
            "instructionVersion": instructionVersion,
            "instructionHash": instructionHash,
            "buildIdentity": buildIdentity,
        ]
    }

    func correlationArgumentDefinition() -> [String: Any] {
        Self.deepCopy(correlationArgumentDefinitionValue) as! [String: Any]
    }

    func toolDefinitions(handler: String, commandsEnabled: Bool = true, observabilityEnabled: Bool = true) -> [[String: Any]] {
        tools.compactMap { item in
            guard (item["handler"] as? String) == handler else { return nil }
            let availability = item["availability"] as? [String: Any] ?? [:]
            if (availability["requiresCommands"] as? Bool) == true && !commandsEnabled { return nil }
            if (availability["requiresObservability"] as? Bool) == true && !observabilityEnabled { return nil }
            guard let definition = item["definition"] as? [String: Any] else { return nil }
            return Self.deepCopy(definition) as? [String: Any]
        }
    }

    func toolDefinition(named name: String) throws -> [String: Any] {
        guard let item = tools.first(where: { ($0["name"] as? String) == name }),
              let definition = item["definition"] as? [String: Any],
              let copy = Self.deepCopy(definition) as? [String: Any] else {
            throw ToolCatalogError.invalid("Canonical tool catalog is missing tool: \(name)")
        }
        return copy
    }

    func toolPolicyMetadata(named name: String) throws -> ToolPolicyMetadata {
        guard let item = tools.first(where: { ($0["name"] as? String) == name }),
              let risk = item["risk"] as? String,
              let effect = item["effect"] as? String,
              let capabilities = item["capabilities"] as? [String] else {
            throw ToolCatalogError.invalid("Canonical tool catalog is missing policy metadata for: \(name)")
        }
        return ToolPolicyMetadata(name: name, risk: risk, effect: effect, capabilities: capabilities)
    }

    func containsTool(named name: String) -> Bool {
        tools.contains { ($0["name"] as? String) == name }
    }

    func validateHandlerCoverage(handler: String, runtimeHandlerNames: Set<String>) throws {
        let expected = Set(tools.compactMap { item -> String? in
            guard (item["handler"] as? String) == handler else { return nil }
            return item["name"] as? String
        })
        let missing = expected.subtracting(runtimeHandlerNames).sorted()
        let extra = runtimeHandlerNames.subtracting(expected).sorted()
        guard missing.isEmpty, extra.isEmpty else {
            throw ToolCatalogError.invalid("Canonical tool handler coverage mismatch for '\(handler)': missing=[\(missing.joined(separator: ","))] extra=[\(extra.joined(separator: ","))]")
        }
    }

    func validateProtocolContract(modern: String, legacy: [String]) throws {
        guard modern == modernProtocolVersion else {
            throw ToolCatalogError.invalid("Canonical catalog modern protocol mismatch: runtime=\(modern) catalog=\(modernProtocolVersion)")
        }
        guard Set(legacy) == Set(legacyProtocolVersions) else {
            throw ToolCatalogError.invalid("Canonical catalog legacy protocol set does not match runtime protocol constants")
        }
    }

    private static func load() throws -> CanonicalToolCatalog {
        var candidates: [URL] = []
        if let resource = Bundle.main.resourceURL {
            candidates.append(resource.appendingPathComponent("tool_catalog.v1.json", isDirectory: false))
        }
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("contracts/tool_catalog.v1.json", isDirectory: false)
        candidates.append(source)
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw ToolCatalogError.invalid("Canonical tool catalog file is missing")
        }
        return try decode(Data(contentsOf: url))
    }

    static func fromPayloadForTest(_ data: Data) throws -> CanonicalToolCatalog {
        try decode(data)
    }

    private static func decode(_ data: Data) throws -> CanonicalToolCatalog {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ToolCatalogError.invalid("Malformed canonical tool catalog JSON: \(error.localizedDescription)")
        }
        guard let root = object as? [String: Any] else {
            throw ToolCatalogError.invalid("Canonical tool catalog root must be a JSON object")
        }
        return try CanonicalToolCatalog(data: data, root: root)
    }

    private static func requiredString(_ object: [String: Any], _ key: String) throws -> String {
        guard let value = object[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolCatalogError.invalid("Canonical tool catalog field '\(key)' must be a non-empty string")
        }
        return value
    }

    private static func requiredObject(_ object: [String: Any], _ key: String) throws -> [String: Any] {
        guard let value = object[key] as? [String: Any] else {
            throw ToolCatalogError.invalid("Canonical tool catalog field '\(key)' must be an object")
        }
        return value
    }

    private static func requiredStringArray(_ object: [String: Any], _ key: String) throws -> [String] {
        guard let value = object[key] as? [String], value.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ToolCatalogError.invalid("Canonical tool catalog field '\(key)' must be an array of non-empty strings")
        }
        return value
    }

    private static func composeInstructions(_ base: String, _ observabilitySuffix: String) -> String {
        base + observabilitySuffix
    }

    private static func normalizedCatalogData(_ data: Data) throws -> Data {
        guard var text = String(data: data, encoding: .utf8) else {
            throw ToolCatalogError.invalid("Canonical tool catalog must be valid UTF-8")
        }
        if text.unicodeScalars.first?.value == 0xFEFF { text.removeFirst() }
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return Data(text.utf8)
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func deepCopy(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return Dictionary(uniqueKeysWithValues: dictionary.map { ($0.key, deepCopy($0.value)) })
        }
        if let array = value as? [Any] { return array.map(deepCopy) }
        return value
    }
}
