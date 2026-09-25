import Foundation
import Security
import CryptoKit

enum AuthenticatedCursorError: LocalizedError {
    case invalid(String)
    case randomFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .invalid(message): return message
        case let .randomFailure(status): return "Could not generate cursor key (OSStatus \(status))"
        }
    }
}

final class AuthenticatedCursorCodec {
    static let cursorMetadataKey = "io.filemcp/cursor"
    static let defaultMaxLifetime: TimeInterval = 15 * 60

    private let key: SymmetricKey
    private let nowProvider: () -> Date
    private let maxLifetime: TimeInterval
    private static let maxEncodedCursorChars = 4096
    private static let maxPayloadBytes = 2048

    init(
        keyData: Data? = nil,
        nowProvider: @escaping () -> Date = Date.init,
        maxLifetime: TimeInterval = defaultMaxLifetime
    ) throws {
        let bytes: Data
        if let keyData {
            guard keyData.count >= 32 else {
                throw AuthenticatedCursorError.invalid("Cursor key must be at least 32 bytes")
            }
            bytes = keyData
        } else {
            var random = [UInt8](repeating: 0, count: 32)
            let status = SecRandomCopyBytes(kSecRandomDefault, random.count, &random)
            guard status == errSecSuccess else { throw AuthenticatedCursorError.randomFailure(status) }
            bytes = Data(random)
        }
        guard maxLifetime > 0, maxLifetime <= 60 * 60 else {
            throw AuthenticatedCursorError.invalid("Cursor max lifetime must be positive and no more than one hour")
        }
        self.key = SymmetricKey(data: bytes)
        self.nowProvider = nowProvider
        self.maxLifetime = maxLifetime
    }

    func encode(
        tool: String,
        optionsHash: String,
        rootAuthorityID: String,
        generation: Int64,
        position: String,
        expiresAt: Date
    ) throws -> String {
        try Self.validateBoundString(tool, name: "tool", max: 128)
        try Self.validateBoundString(optionsHash, name: "optionsHash", max: 256)
        try Self.validateBoundString(rootAuthorityID, name: "rootAuthorityID", max: 512)
        try Self.validateBoundString(position, name: "position", max: 1024)
        guard generation >= 0 else { throw AuthenticatedCursorError.invalid("Cursor generation must not be negative") }

        let now = nowProvider()
        let lifetime = expiresAt.timeIntervalSince(now)
        guard lifetime > 0, lifetime <= maxLifetime else {
            throw AuthenticatedCursorError.invalid("Cursor expiry must be within \(Int(maxLifetime / 60)) minutes")
        }

        let payload: [String: Any] = [
            "v": 1,
            "tool": tool,
            "optionsHash": optionsHash,
            "rootAuthorityId": rootAuthorityID,
            "generation": generation,
            "position": position,
            "expiresUnixMs": Int64(expiresAt.timeIntervalSince1970 * 1000),
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        guard payloadData.count <= Self.maxPayloadBytes else {
            throw AuthenticatedCursorError.invalid("Cursor payload is too large")
        }

        let signature = Data(HMAC<SHA256>.authenticationCode(for: payloadData, using: key))
        return Self.base64URL(payloadData) + "." + Self.base64URL(signature)
    }

    func decode(
        _ cursor: String,
        expectedTool: String,
        expectedOptionsHash: String,
        expectedRootAuthorityID: String,
        expectedGeneration: Int64,
        now: Date
    ) throws -> String {
        guard !cursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              cursor.count <= Self.maxEncodedCursorChars else {
            throw AuthenticatedCursorError.invalid("Malformed cursor")
        }
        let parts = cursor.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let payloadData = Self.fromBase64URL(String(parts[0])),
              let signature = Self.fromBase64URL(String(parts[1])),
              !payloadData.isEmpty,
              payloadData.count <= Self.maxPayloadBytes,
              signature.count == 32 else {
            throw AuthenticatedCursorError.invalid("Malformed cursor")
        }

        guard HMAC<SHA256>.isValidAuthenticationCode(signature, authenticating: payloadData, using: key) else {
            throw AuthenticatedCursorError.invalid("Cursor authentication failed")
        }

        guard let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              (payload["v"] as? NSNumber)?.intValue == 1 else {
            throw AuthenticatedCursorError.invalid("Malformed cursor payload")
        }
        guard payload["tool"] as? String == expectedTool else {
            throw AuthenticatedCursorError.invalid("Cursor tool mismatch")
        }
        guard payload["optionsHash"] as? String == expectedOptionsHash else {
            throw AuthenticatedCursorError.invalid("Cursor options mismatch")
        }
        guard payload["rootAuthorityId"] as? String == expectedRootAuthorityID else {
            throw AuthenticatedCursorError.invalid("Cursor root mismatch")
        }
        guard let generation = payload["generation"] as? NSNumber, generation.int64Value == expectedGeneration else {
            throw AuthenticatedCursorError.invalid("Cursor generation is stale")
        }
        guard let expiry = payload["expiresUnixMs"] as? NSNumber,
              Int64(now.timeIntervalSince1970 * 1000) < expiry.int64Value else {
            throw AuthenticatedCursorError.invalid("Cursor expired")
        }
        guard let position = payload["position"] as? String, !position.isEmpty else {
            throw AuthenticatedCursorError.invalid("Cursor position missing")
        }
        return position
    }

    static func stableHash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func validateBoundString(_ value: String, name: String, max: Int) throws {
        guard !value.isEmpty, value.count <= max else {
            throw AuthenticatedCursorError.invalid("\(name) must contain 1...\(max) characters")
        }
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func fromBase64URL(_ value: String) -> Data? {
        guard !value.isEmpty, value.count <= maxEncodedCursorChars else { return nil }
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: base64)
    }
}
