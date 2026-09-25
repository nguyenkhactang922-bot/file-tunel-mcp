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
        warnings: [String] = [],
        usage: [String: Any]? = nil,
        forceTruncated: Bool = false,
        truncationDetail: String? = nil
    ) -> [String: Any] {
        let structuredTruncated = structuredContent?["truncated"] as? Bool ?? false
        let truncated = forceTruncated || structuredTruncated

        var truncation: [String: Any] = [
            "truncated": truncated,
            "reason": truncated ? "server_limit" : "none",
        ]
        if truncated, let detail = truncationDetail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
            truncation["detail"] = detail
        }

        var usageValue: [String: Any] = ["contentItems": content.count]
        if let usage {
            for (key, value) in usage where key != "contentItems" {
                usageValue[key] = value
            }
        }

        let envelope: [String: Any] = [
            "schemaVersion": schemaVersion,
            "status": isError ? "tool_error" : (truncated ? "partial" : "success"),
            "operationId": "op_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            "truncation": truncation,
            "usage": usageValue,
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
        warnings: [String] = [],
        usage: [String: Any]? = nil,
        forceTruncated: Bool = false,
        truncationDetail: String? = nil
    ) {
        var meta = result["_meta"] as? [String: Any] ?? [:]
        meta[metadataKey] = create(
            isError: isError,
            content: content,
            structuredContent: structuredContent,
            warnings: warnings,
            usage: usage,
            forceTruncated: forceTruncated,
            truncationDetail: truncationDetail
        )
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
        if let detail = truncation["detail"] {
            guard let detail = detail as? String,
                  !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  detail.count <= 64 else {
                throw ToolResultEnvelopeError.invalid("Malformed tool result envelope truncation detail")
            }
        }
        if status == "partial" && !truncated {
            throw ToolResultEnvelopeError.invalid("Partial tool result envelope must be truncated")
        }
        if status == "success" && truncated {
            throw ToolResultEnvelopeError.invalid("Successful tool result envelope cannot be truncated")
        }

        guard let usage = envelope["usage"] as? [String: Any],
              let contentItems = integer(usage["contentItems"]), contentItems >= 0 else {
            throw ToolResultEnvelopeError.invalid("Malformed tool result envelope usage")
        }
        for key in ["visitedEntries", "filesScanned", "outputItems"] {
            if let raw = usage[key], (integer(raw) ?? -1) < 0 {
                throw ToolResultEnvelopeError.invalid("Malformed tool result envelope usage field: \(key)")
            }
        }
        if let raw = usage["bytesScanned"], (int64(raw) ?? -1) < 0 {
            throw ToolResultEnvelopeError.invalid("Malformed tool result envelope usage field: bytesScanned")
        }
        if let raw = usage["truncated"], !(raw is Bool) {
            throw ToolResultEnvelopeError.invalid("Malformed tool result envelope usage field: truncated")
        }
        if let raw = usage["truncationReason"] {
            guard let reason = raw as? String,
                  !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  reason.count <= 64 else {
                throw ToolResultEnvelopeError.invalid("Malformed tool result envelope usage field: truncationReason")
            }
        }

        guard let warnings = envelope["warnings"] as? [String],
              warnings.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ToolResultEnvelopeError.invalid("Malformed tool result envelope warnings")
        }
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let value, !(value is Bool), let number = value as? NSNumber else { return nil }
        let result = number.intValue
        return number.doubleValue == Double(result) ? result : nil
    }

    private static func int64(_ value: Any?) -> Int64? {
        guard let value, !(value is Bool), let number = value as? NSNumber else { return nil }
        let result = number.int64Value
        return number.doubleValue == Double(result) ? result : nil
    }

    private static func isOperationID(_ value: String) -> Bool {
        guard value.hasPrefix("op_"), value.count == 35 else { return false }
        return value.dropFirst(3).allSatisfy { character in
            character.isNumber || (character >= "a" && character <= "f")
        }
    }
}
