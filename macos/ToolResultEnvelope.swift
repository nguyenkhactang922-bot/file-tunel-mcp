import Foundation

enum ToolResultEnvelopeError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case let .invalid(message): return message }
    }
}

enum ToolResultEnvelope {
    static let metadataKey = "io.filemcp/result"
    static let schemaVersion = "1.0.0"
    private static let statuses: Set<String> = ["success", "partial", "tool_error"]
    private static let truncationReasons: Set<String> = ["none", "server_limit", "output_limit", "unknown"]

    static func create(
        isError: Bool,
        content: [[String: Any]],
        structuredContent: [String: Any]?,
        warnings: [String] = []
    ) -> [String: Any] {
        let truncated = structuredContent?["truncated"] as? Bool ?? false
        let envelope: [String: Any] = [
            "schemaVersion": schemaVersion,
            "status": isError ? "tool_error" : (truncated ? "partial" : "success"),
            "operationId": "op_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            "truncation": [
                "truncated": truncated,
                "reason": truncated ? "server_limit" : "none",
            ],
            "usage": ["contentItems": content.count],
            "warnings": warnings,
        ]
        do { try validate(envelope) }
        catch { preconditionFailure("Invalid internally-created tool result envelope: \(error.localizedDescription)") }
        return envelope
    }

    static func attach(
        to result: inout [String: Any],
        isError: Bool,
        content: [[String: Any]],
        structuredContent: [String: Any]?,
        warnings: [String] = []
    ) {
        var meta = result["_meta"] as? [String: Any] ?? [:]
        meta[metadataKey] = create(isError: isError, content: content, structuredContent: structuredContent, warnings: warnings)
        result["_meta"] = meta
    }

    static func require(from result: [String: Any]) throws -> [String: Any] {
        guard let meta = result["_meta"] as? [String: Any],
              let envelope = meta[metadataKey] as? [String: Any] else {
            throw ToolResultEnvelopeError.invalid("Missing tool result envelope metadata")
        }
        try validate(envelope)
        return envelope
    }

    static func validate(_ envelope: [String: Any]) throws {
        guard envelope["schemaVersion"] as? String == schemaVersion else {
            throw ToolResultEnvelopeError.invalid("Unknown tool result envelope schemaVersion")
        }
        guard let status = envelope["status"] as? String, statuses.contains(status) else {
            throw ToolResultEnvelopeError.invalid("Unknown tool result envelope status")
        }
        guard let operationId = envelope["operationId"] as? String, isOperationID(operationId) else {
            throw ToolResultEnvelopeError.invalid("Malformed tool result envelope operationId")
        }
        guard let truncation = envelope["truncation"] as? [String: Any],
              let truncated = truncation["truncated"] as? Bool,
              let reason = truncation["reason"] as? String,
              truncationReasons.contains(reason) else {
            throw ToolResultEnvelopeError.invalid("Malformed tool result envelope truncation")
        }
        guard (truncated && reason != "none") || (!truncated && reason == "none") else {
            throw ToolResultEnvelopeError.invalid("Inconsistent tool result envelope truncation")
        }
        if status == "partial" && !truncated {
            throw ToolResultEnvelopeError.invalid("Partial tool result envelope must be truncated")
        }
        if status == "success" && truncated {
            throw ToolResultEnvelopeError.invalid("Successful tool result envelope cannot be truncated")
        }
        guard let usage = envelope["usage"] as? [String: Any],
              let contentItems = usage["contentItems"] as? Int, contentItems >= 0 else {
            throw ToolResultEnvelopeError.invalid("Malformed tool result envelope usage")
        }
        guard let warnings = envelope["warnings"] as? [String],
              warnings.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ToolResultEnvelopeError.invalid("Malformed tool result envelope warnings")
        }
    }

    private static func isOperationID(_ value: String) -> Bool {
        guard value.hasPrefix("op_"), value.count == 35 else { return false }
        return value.dropFirst(3).allSatisfy { character in
            character.isNumber || (character >= "a" && character <= "f")
        }
    }
}
