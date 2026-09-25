import Foundation
import CoreFoundation

enum ExecProcessEnvironmentAuthorityError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

final class ExecProcessEnvironmentAuthority {
    static let maxPatterns = 32
    static let maxOverrides = 32
    static let maxNameChars = 128
    static let maxValueChars = 8_192
    static let maxTotalOverrideChars = 16_384
    static let maxForwardedVariables = 64
    static let maxForwardedValueChars = 16_384
    static let maxEnvironmentChars = 32_000

    private static let minimalBaselineNames: Set<String> = [
        "PATH", "HOME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "USER", "LOGNAME",
    ]
    private static let secretMarkers = [
        "TOKEN", "SECRET", "PASSWORD", "PASSWD", "API_KEY", "APIKEY",
        "PRIVATE_KEY", "ACCESS_KEY", "CLIENT_SECRET", "CREDENTIAL", "BEARER", "COOKIE",
    ]

    let patterns: [String]

    init(patterns: [String] = []) throws {
        self.patterns = try Self.normalizePatterns(patterns)
    }

    static func normalizePatterns(_ patterns: [String]) throws -> [String] {
        var result: [String] = []
        for raw in patterns {
            let pattern = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if pattern.isEmpty { continue }
            try validatePattern(pattern)
            if !result.contains(pattern) { result.append(pattern) }
            if result.count > maxPatterns {
                throw ExecProcessEnvironmentAuthorityError.invalid("exec_process environment allowlist supports at most \(maxPatterns) entries")
            }
        }
        return result
    }

    func build(overrides: [String: String] = [:], host: [String: String] = ProcessInfo.processInfo.environment) throws -> [String: String] {
        var result: [String: String] = [:]
        var environmentChars = 0

        func setBounded(_ name: String, _ value: String) throws {
            guard value.count <= Self.maxForwardedValueChars else {
                throw ExecProcessEnvironmentAuthorityError.invalid("Environment variable \(name) exceeds \(Self.maxForwardedValueChars) characters")
            }
            let previousChars = result[name].map { name.count + $0.count } ?? 0
            if result[name] == nil, result.count >= Self.maxForwardedVariables {
                throw ExecProcessEnvironmentAuthorityError.invalid("exec_process environment exceeds \(Self.maxForwardedVariables) forwarded variables")
            }
            let nextChars = environmentChars - previousChars + name.count + value.count
            guard nextChars <= Self.maxEnvironmentChars else {
                throw ExecProcessEnvironmentAuthorityError.invalid("exec_process environment exceeds \(Self.maxEnvironmentChars) total characters")
            }
            result[name] = value
            environmentChars = nextChars
        }

        for name in Self.minimalBaselineNames {
            if let value = host[name], !value.isEmpty { try setBounded(name, value) }
        }
        for (name, value) in host {
            guard let matching = matchingPattern(name) else { continue }
            if Self.isSecretLike(name), Self.containsWildcard(matching) { continue }
            try setBounded(name, value)
        }

        guard overrides.count <= Self.maxOverrides else {
            throw ExecProcessEnvironmentAuthorityError.invalid("exec_process environment supports at most \(Self.maxOverrides) overrides")
        }
        var totalChars = 0
        for (name, value) in overrides {
            try Self.validateName(name)
            guard !value.utf8.contains(0) else { throw ExecProcessEnvironmentAuthorityError.invalid("Environment override \(name) contains a NUL byte") }
            guard value.count <= Self.maxValueChars else { throw ExecProcessEnvironmentAuthorityError.invalid("Environment override \(name) exceeds \(Self.maxValueChars) characters") }
            totalChars += name.count + value.count
            guard totalChars <= Self.maxTotalOverrideChars else { throw ExecProcessEnvironmentAuthorityError.invalid("exec_process environment overrides exceed the total size limit") }

            guard let matching = matchingPattern(name) else {
                throw ExecProcessEnvironmentAuthorityError.invalid("Environment override is not locally allowed: \(name)")
            }
            if Self.isSecretLike(name), Self.containsWildcard(matching) {
                throw ExecProcessEnvironmentAuthorityError.invalid("Secret-like environment override requires an exact local allowlist entry: \(name)")
            }
            try setBounded(name, value)
        }
        return result
    }

    static func isSecretLike(_ name: String) -> Bool {
        let upper = name.uppercased()
        return secretMarkers.contains { upper.contains($0) }
    }

    private func matchingPattern(_ name: String) -> String? {
        patterns.first { Self.globMatches($0, name) }
    }

    private static func containsWildcard(_ pattern: String) -> Bool { pattern.contains("*") || pattern.contains("?") }

    private static func globMatches(_ pattern: String, _ value: String) -> Bool {
        var regex = "^"
        for scalar in pattern.unicodeScalars {
            switch Character(String(scalar)) {
            case "*": regex += ".*"
            case "?": regex += "."
            default: regex += NSRegularExpression.escapedPattern(for: String(scalar))
            }
        }
        regex += "$"
        return (try? NSRegularExpression(pattern: regex).firstMatch(in: value, range: NSRange(value.startIndex..., in: value))) != nil
    }

    private static func validatePattern(_ pattern: String) throws {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-*?"))
        guard pattern.count <= maxNameChars,
              !pattern.utf8.contains(0), !pattern.contains("="),
              pattern.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ExecProcessEnvironmentAuthorityError.invalid("Invalid exec_process environment allowlist pattern: \(pattern)")
        }
    }

    private static func validateName(_ name: String) throws {
        guard !name.isEmpty, name.count <= maxNameChars, !name.utf8.contains(0), !name.contains("=") else {
            throw ExecProcessEnvironmentAuthorityError.invalid("Invalid environment variable name: \(name)")
        }
        guard name.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil else {
            throw ExecProcessEnvironmentAuthorityError.invalid("Invalid environment variable name: \(name)")
        }
    }
}
