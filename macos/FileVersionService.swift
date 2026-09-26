import Foundation
import Darwin
import CryptoKit
import Security

enum FileVersionServiceError: LocalizedError {
    case invalid(String)
    case io(String)

    var errorDescription: String? {
        switch self {
        case let .invalid(message), let .io(message): return message
        }
    }
}

struct FileVersionPayload: Codable, Equatable {
    let schema: Int
    let pathFingerprint: String
    let identityFingerprint: String
    let entryType: String
    let sizeBytes: Int64
    let modifiedStamp: String
    let changedStamp: String
    let strength: String
    let contentHash: String
}

struct FileVersionedRead {
    let data: Data
    let versionToken: String
    let versionFingerprint: String
    let sizeBytes: Int64
    let contentHash: String
    let pathFingerprint: String
}

final class FileVersionService {
    static let tokenSchemaVersion = 1
    static let providerVersion = "file-version-v1"
    private static let maxEncodedTokenChars = 4096
    private static let maxPayloadBytes = 2048
    private static let hashChunkBytes = 64 * 1024
    private static let processSigningKey: Data = {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Could not generate FileMCP file-version signing key")
        return Data(bytes)
    }()

    private let resolver: SafePathResolver
    private let key: SymmetricKey

    init(resolver: SafePathResolver, keyData: Data? = nil) throws {
        self.resolver = resolver
        let bytes = keyData ?? Self.processSigningKey
        guard bytes.count >= 32 else {
            throw FileVersionServiceError.invalid("File version signing key must be at least 32 bytes")
        }
        self.key = SymmetricKey(data: bytes)
    }

    func readVersioned(relativePath: String, maxBytes: Int) throws -> FileVersionedRead {
        guard maxBytes > 0 else { throw FileVersionServiceError.invalid("maxBytes must be positive") }
        let target = try resolver.resolve(relativePath)
        let handle = try FileHandle(forReadingFrom: target)
        defer { try? handle.close() }
        let before = try snapshot(fileDescriptor: handle.fileDescriptor)
        guard before.entryType == "file" else {
            throw FileVersionServiceError.invalid("No such file: \(relativePath)")
        }
        guard before.sizeBytes <= Int64(maxBytes) else {
            throw FileVersionServiceError.invalid("File is larger than the 5 MB limit for this tool")
        }

        var data = Data()
        data.reserveCapacity(Int(before.sizeBytes))
        while true {
            let chunk = try handle.read(upToCount: Self.hashChunkBytes) ?? Data()
            if chunk.isEmpty { break }
            guard data.count <= maxBytes - chunk.count else {
                throw FileVersionServiceError.invalid("File is larger than the 5 MB limit for this tool")
            }
            data.append(chunk)
        }
        let after = try snapshot(path: target)
        guard before == after, Int64(data.count) == before.sizeBytes else {
            throw FileVersionServiceError.invalid("File changed while its strong version was being captured")
        }

        let canonicalRelative = relativePathForVersion(target)
        let contentHash = Self.sha256Tagged(data)
        let payload = FileVersionPayload(
            schema: Self.tokenSchemaVersion,
            pathFingerprint: Self.sha256Tagged(Data((resolver.root.path + "\0" + canonicalRelative + "\0" + target.path).utf8)),
            identityFingerprint: before.identityFingerprint,
            entryType: before.entryType,
            sizeBytes: before.sizeBytes,
            modifiedStamp: before.modifiedStamp,
            changedStamp: before.changedStamp,
            strength: "content",
            contentHash: contentHash
        )
        let payloadData = try encodePayload(payload)
        return FileVersionedRead(
            data: data,
            versionToken: try encodeToken(payloadData),
            versionFingerprint: Self.sha256Tagged(payloadData),
            sizeBytes: before.sizeBytes,
            contentHash: contentHash,
            pathFingerprint: payload.pathFingerprint
        )
    }

    func verifyExpectedVersion(relativePath: String, token: String, maxBytes: Int) throws -> FileVersionPayload {
        let currentRead = try readExpectedVersioned(relativePath: relativePath, token: token, maxBytes: maxBytes)
        return try decodeToken(currentRead.versionToken)
    }

    func readExpectedVersioned(relativePath: String, token: String, maxBytes: Int) throws -> FileVersionedRead {
        let expected = try decodeToken(token)
        let currentRead = try readVersioned(relativePath: relativePath, maxBytes: maxBytes)
        let current = try decodeToken(currentRead.versionToken)
        guard current.pathFingerprint == expected.pathFingerprint else {
            throw FileVersionServiceError.invalid("Version token belongs to a different path or scope")
        }
        guard current.identityFingerprint == expected.identityFingerprint else {
            throw FileVersionServiceError.invalid("Target was replaced since the version token was captured")
        }
        guard current == expected else {
            throw FileVersionServiceError.invalid("File changed since the version token was captured")
        }
        return currentRead
    }

    func decodeForTest(_ token: String) throws -> FileVersionPayload { try decodeToken(token) }

    static func sha256Tagged(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Tagged(_ value: String) -> String { sha256Tagged(Data(value.utf8)) }

    static func sha256File(_ url: URL, maxBytes: Int64) throws -> (hash: String, bytesRead: Int64) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var bytesRead: Int64 = 0
        while true {
            let chunk = try handle.read(upToCount: hashChunkBytes) ?? Data()
            if chunk.isEmpty { break }
            bytesRead += Int64(chunk.count)
            guard bytesRead <= maxBytes else {
                throw FileVersionServiceError.invalid("SourceStateRef file hashing exceeded the aggregate limit")
            }
            hasher.update(data: chunk)
        }
        return ("sha256:" + hasher.finalize().map { String(format: "%02x", $0) }.joined(), bytesRead)
    }

    private func relativePathForVersion(_ target: URL) -> String {
        let root = resolver.root.path
        let path = target.resolvingSymlinksInPath().standardizedFileURL.path
        guard path != root, path.hasPrefix(root + "/") else { return "" }
        return String(path.dropFirst(root.count + 1))
    }

    private func encodePayload(_ payload: FileVersionPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        guard !data.isEmpty, data.count <= Self.maxPayloadBytes else {
            throw FileVersionServiceError.invalid("File version payload is too large")
        }
        return data
    }

    private func encodeToken(_ payloadData: Data) throws -> String {
        let encoded = Self.base64URL(payloadData)
        let signature = Data(HMAC<SHA256>.authenticationCode(for: Data(encoded.utf8), using: key))
        return "v\(Self.tokenSchemaVersion):\(encoded):\(Self.base64URL(signature))"
    }

    private func decodeToken(_ token: String) throws -> FileVersionPayload {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              token.count <= Self.maxEncodedTokenChars else {
            throw FileVersionServiceError.invalid("Unsupported or malformed file version token")
        }
        let parts = token.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "v\(Self.tokenSchemaVersion)",
              let payloadData = Self.fromBase64URL(String(parts[1])),
              let signature = Self.fromBase64URL(String(parts[2])),
              !payloadData.isEmpty, payloadData.count <= Self.maxPayloadBytes, signature.count == 32 else {
            throw FileVersionServiceError.invalid("Unsupported or malformed file version token")
        }
        let encoded = String(parts[1])
        guard HMAC<SHA256>.isValidAuthenticationCode(signature, authenticating: Data(encoded.utf8), using: key) else {
            throw FileVersionServiceError.invalid("File version token authentication failed")
        }
        do {
            let payload = try JSONDecoder().decode(FileVersionPayload.self, from: payloadData)
            guard payload.schema == Self.tokenSchemaVersion,
                  payload.strength == "content",
                  !payload.pathFingerprint.isEmpty,
                  !payload.identityFingerprint.isEmpty,
                  !payload.contentHash.isEmpty,
                  payload.sizeBytes >= 0 else {
                throw FileVersionServiceError.invalid("Unsupported or malformed file version payload")
            }
            return payload
        } catch let error as FileVersionServiceError {
            throw error
        } catch {
            throw FileVersionServiceError.invalid("Unsupported or malformed file version payload")
        }
    }

    private func snapshot(path: URL) throws -> FileSnapshot {
        let handle = try FileHandle(forReadingFrom: path)
        defer { try? handle.close() }
        return try snapshot(fileDescriptor: handle.fileDescriptor)
    }

    private func snapshot(fileDescriptor: Int32) throws -> FileSnapshot {
        var value = stat()
        guard fstat(fileDescriptor, &value) == 0 else {
            throw FileVersionServiceError.io("Could not read native file identity: errno \(errno)")
        }
        let type = value.st_mode & S_IFMT
        let entryType = type == S_IFREG ? "file" : (type == S_IFDIR ? "directory" : "other")
        var identityData = Data()
        var device = value.st_dev
        var inode = value.st_ino
        withUnsafeBytes(of: &device) { identityData.append(contentsOf: $0) }
        withUnsafeBytes(of: &inode) { identityData.append(contentsOf: $0) }
        return FileSnapshot(
            identityFingerprint: Self.sha256Tagged(identityData),
            entryType: entryType,
            sizeBytes: Int64(value.st_size),
            modifiedStamp: "\(value.st_mtimespec.tv_sec):\(value.st_mtimespec.tv_nsec)",
            changedStamp: "\(value.st_ctimespec.tv_sec):\(value.st_ctimespec.tv_nsec)"
        )
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func fromBase64URL(_ value: String) -> Data? {
        guard !value.isEmpty, value.count <= maxEncodedTokenChars else { return nil }
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: base64)
    }

    private struct FileSnapshot: Equatable {
        let identityFingerprint: String
        let entryType: String
        let sizeBytes: Int64
        let modifiedStamp: String
        let changedStamp: String
    }
}
