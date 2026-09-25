import Foundation
import Darwin

enum AuthorizedPathSnapshotError: LocalizedError {
    case invalid(String)
    case system(String)

    var errorDescription: String? {
        switch self {
        case let .invalid(message), let .system(message): return message
        }
    }
}

struct NativeAuthorizedPathIdentity: Equatable {
    let device: UInt64
    let inode: UInt64
    let isDirectory: Bool
    let isSymlink: Bool
}

struct AuthorizedPathAncestor: Equatable {
    let path: String
    let identity: NativeAuthorizedPathIdentity
}

struct AuthorizedPathSnapshot {
    let relativePath: String
    let lexicalTargetPath: String
    let ancestors: [AuthorizedPathAncestor]
    let targetIdentity: NativeAuthorizedPathIdentity?
    let expectedLeafAbsent: Bool
}

final class AuthorizedPathSnapshotService {
    private let resolver: SafePathResolver

    init(resolver: SafePathResolver) {
        self.resolver = resolver
    }

    func captureExisting(relativePath: String) throws -> AuthorizedPathSnapshot {
        let lexicalTarget = try lexicalTarget(relativePath)
        _ = try resolver.resolveForDeletion(relativePath)
        let parent = try requireParent(lexicalTarget)
        let ancestors = try captureAncestorChain(parentPath: parent)
        let targetIdentity = try captureIdentityRequired(path: lexicalTarget, allowSymlink: true, requireDirectory: nil)
        return AuthorizedPathSnapshot(
            relativePath: relativePath,
            lexicalTargetPath: lexicalTarget.path,
            ancestors: ancestors,
            targetIdentity: targetIdentity,
            expectedLeafAbsent: false
        )
    }

    func captureNewTarget(relativePath: String) throws -> AuthorizedPathSnapshot {
        let lexicalTarget = try lexicalTarget(relativePath)
        _ = try resolver.resolve(relativePath)
        let parent = try requireParent(lexicalTarget)
        let ancestors = try captureAncestorChain(parentPath: parent)
        if try captureIdentity(path: lexicalTarget, allowSymlink: true, requireDirectory: nil) != nil {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard expected the target leaf to be absent")
        }
        return AuthorizedPathSnapshot(
            relativePath: relativePath,
            lexicalTargetPath: lexicalTarget.path,
            ancestors: ancestors,
            targetIdentity: nil,
            expectedLeafAbsent: true
        )
    }

    @discardableResult
    func verify(_ snapshot: AuthorizedPathSnapshot) throws -> URL {
        let lexicalTarget = try lexicalTarget(snapshot.relativePath)
        guard lexicalTarget.path == snapshot.lexicalTargetPath else {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard target path changed since authorization")
        }
        _ = try resolver.resolveForDeletion(snapshot.relativePath)
        let parent = try requireParent(lexicalTarget)
        let currentAncestors = try captureAncestorChain(parentPath: parent)
        guard currentAncestors.count == snapshot.ancestors.count else {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard ancestor chain changed since authorization")
        }
        for (expected, current) in zip(snapshot.ancestors, currentAncestors) {
            guard expected.path == current.path, expected.identity == current.identity else {
                throw AuthorizedPathSnapshotError.invalid("Mutation Guard ancestor identity changed since authorization")
            }
        }

        let currentTarget = try captureIdentity(path: lexicalTarget, allowSymlink: true, requireDirectory: nil)
        if snapshot.expectedLeafAbsent {
            guard currentTarget == nil else {
                throw AuthorizedPathSnapshotError.invalid("Mutation Guard expected target leaf absence but an entry now exists")
            }
        } else {
            guard let expected = snapshot.targetIdentity else {
                throw AuthorizedPathSnapshotError.invalid("Mutation Guard snapshot is invalid: existing target identity is missing")
            }
            guard let currentTarget else {
                throw AuthorizedPathSnapshotError.invalid("Mutation Guard target disappeared since authorization")
            }
            guard currentTarget == expected else {
                throw AuthorizedPathSnapshotError.invalid("Mutation Guard target identity changed since authorization")
            }
        }
        return lexicalTarget
    }

    private func lexicalTarget(_ relativePath: String) throws -> URL {
        let ns = relativePath as NSString
        guard !ns.isAbsolutePath, !relativePath.hasPrefix("/") else {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard refused a path outside the shared directory")
        }
        let rootPath = resolver.root.path
        let lexical = resolver.root.appendingPathComponent(relativePath).standardizedFileURL
        guard lexical.path == rootPath || lexical.path.hasPrefix(rootPath + "/") else {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard refused a path outside the shared directory")
        }
        guard lexical.path != rootPath else {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard does not authorize the shared root as a mutation target")
        }
        return lexical
    }

    private func requireParent(_ target: URL) throws -> URL {
        let parent = target.deletingLastPathComponent().standardizedFileURL
        guard parent.path != target.path else {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard target parent is unavailable")
        }
        return parent
    }

    private func captureAncestorChain(parentPath: URL) throws -> [AuthorizedPathAncestor] {
        let root = resolver.root.standardizedFileURL
        let parent = parentPath.standardizedFileURL
        guard parent.path == root.path || parent.path.hasPrefix(root.path + "/") else {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard parent is outside the shared directory")
        }
        var result: [AuthorizedPathAncestor] = []
        var current = root
        result.append(AuthorizedPathAncestor(
            path: current.path,
            identity: try captureIdentityRequired(path: current, allowSymlink: false, requireDirectory: true)
        ))
        if parent.path == root.path { return result }

        let suffix = String(parent.path.dropFirst(root.path.count + 1))
        for component in suffix.split(separator: "/", omittingEmptySubsequences: true) {
            current.appendPathComponent(String(component), isDirectory: true)
            current = current.standardizedFileURL
            result.append(AuthorizedPathAncestor(
                path: current.path,
                identity: try captureIdentityRequired(path: current, allowSymlink: false, requireDirectory: true)
            ))
        }
        return result
    }

    private func captureIdentityRequired(path: URL, allowSymlink: Bool, requireDirectory: Bool?) throws -> NativeAuthorizedPathIdentity {
        guard let identity = try captureIdentity(path: path, allowSymlink: allowSymlink, requireDirectory: requireDirectory) else {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard path disappeared: \(path.lastPathComponent)")
        }
        return identity
    }

    private func captureIdentity(path: URL, allowSymlink: Bool, requireDirectory: Bool?) throws -> NativeAuthorizedPathIdentity? {
        var before = stat()
        let result = path.path.withCString { pointer in lstat(pointer, &before) }
        guard result == 0 else {
            if errno == ENOENT || errno == ENOTDIR { return nil }
            throw AuthorizedPathSnapshotError.system("Mutation Guard could not inspect \(path.lastPathComponent): \(String(cString: strerror(errno)))")
        }

        let kind = before.st_mode & S_IFMT
        let isSymlink = kind == S_IFLNK
        let isDirectory = kind == S_IFDIR
        if isSymlink && !allowSymlink {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard refused an ancestor symlink")
        }
        if requireDirectory == true && !isDirectory {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard ancestor is not a directory")
        }
        if requireDirectory == false && isDirectory {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard expected a non-directory target")
        }

        let beforeIdentity = identity(from: before, isSymlink: isSymlink, isDirectory: isDirectory)
        if isSymlink { return beforeIdentity }

        let descriptor = path.path.withCString { pointer in open(pointer, O_EVTONLY | O_CLOEXEC | O_NOFOLLOW) }
        guard descriptor >= 0 else {
            if errno == ENOENT || errno == ENOTDIR { return nil }
            if errno == ELOOP { throw AuthorizedPathSnapshotError.invalid("Mutation Guard refused an unexpected symlink") }
            throw AuthorizedPathSnapshotError.system("Mutation Guard could not open \(path.lastPathComponent) without following links: \(String(cString: strerror(errno)))")
        }
        defer { close(descriptor) }
        var after = stat()
        guard fstat(descriptor, &after) == 0 else {
            throw AuthorizedPathSnapshotError.system("Mutation Guard could not read native identity for \(path.lastPathComponent): \(String(cString: strerror(errno)))")
        }
        let afterKind = after.st_mode & S_IFMT
        let afterIdentity = identity(from: after, isSymlink: afterKind == S_IFLNK, isDirectory: afterKind == S_IFDIR)
        guard beforeIdentity == afterIdentity else {
            throw AuthorizedPathSnapshotError.invalid("Mutation Guard path changed while identity was being captured")
        }
        return afterIdentity
    }

    private func identity(from value: stat, isSymlink: Bool, isDirectory: Bool) -> NativeAuthorizedPathIdentity {
        NativeAuthorizedPathIdentity(
            device: UInt64(bitPattern: Int64(value.st_dev)),
            inode: UInt64(value.st_ino),
            isDirectory: isDirectory,
            isSymlink: isSymlink
        )
    }
}
