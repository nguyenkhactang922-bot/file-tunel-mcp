import Foundation
import CryptoKit
import Darwin

final class ProjectContextService {
    static let schemaVersion = "1.0.0"
    static let maxInstructionBytes = 256 * 1024
    static let maxAggregateInstructionBytes: Int64 = 1024 * 1024
    static let maxInstructionSources = 64
    static let defaultMaxLines = 120
    static let maxLines = 500

    private let resolver: SafePathResolver
    private let fileVersions: FileVersionService
    private let pathGuard: AuthorizedPathSnapshotService
    private let cursors: AuthenticatedCursorCodec
    private let skills: CodexSkillRegistry?
    private let policy: ServerPolicy
    private let rootAuthorityID: String

    init(resolver: SafePathResolver, policy: ServerPolicy, skills: CodexSkillRegistry? = nil) throws {
        self.resolver = resolver
        self.policy = policy
        self.skills = skills
        self.fileVersions = try FileVersionService(resolver: resolver)
        self.pathGuard = AuthorizedPathSnapshotService(resolver: resolver)
        self.cursors = try AuthenticatedCursorCodec()
        self.rootAuthorityID = AuthenticatedCursorCodec.stableHash(resolver.root.path)
    }

    func capture(
        path: String,
        cursor: String,
        maxLines: Int,
        includeSkills: Bool,
        context: ToolExecutionContext?
    ) throws -> [String: Any] {
        guard (1...Self.maxLines).contains(maxLines) else {
            throw MCPServerError.invalidArguments("max_lines must be 1..\(Self.maxLines)")
        }
        try requireContinuation(context)

        let scopeDirectory = try resolveScopeDirectory(path)
        let scopeRelative = normalizeRelative(relativePath(for: scopeDirectory))
        let sources = try discoverSources(scopeDirectory: scopeDirectory, context: context)
        let skillSnapshot = includeSkills ? (skills?.snapshotMetadata() ?? []) : []
        let digest = computeDigest(scopeRelative: scopeRelative, sources: sources, skills: skillSnapshot, includeSkills: includeSkills)
        let generation = try generationFromDigest(digest)
        let optionsHash = AuthenticatedCursorCodec.stableHash([
            Self.schemaVersion,
            scopeRelative,
            includeSkills ? "skills:on" : "skills:off",
            String(maxLines),
        ].joined(separator: "\n"))

        var sourceIndex = 0
        var startLine = 1
        if !cursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let position = try cursors.decode(
                cursor,
                expectedTool: "project_context",
                expectedOptionsHash: optionsHash,
                expectedRootAuthorityID: rootAuthorityID,
                expectedGeneration: generation,
                now: Date()
            )
            (sourceIndex, startLine) = try parsePosition(position)
            guard sourceIndex >= 0, sourceIndex < sources.count else {
                throw MCPServerError.invalidArguments("Project context cursor source is no longer available")
            }
        }

        var sourceMetadata: [[String: Any]] = []
        sourceMetadata.reserveCapacity(sources.count)
        for source in sources {
            guard context?.tryOutputItem() ?? true else {
                throw MCPServerError.operationFailed("project_context budget exhausted: \(context?.truncationReason ?? "unknown")")
            }
            sourceMetadata.append([
                "precedence": source.precedence,
                "relative_path": source.relativePath,
                "scope": source.scope,
                "kind": source.kind,
                "size_bytes": source.sizeBytes,
                "version": source.version,
                "version_strength": "content",
                "content_hash": source.contentHash,
                "trust": "repository_untrusted",
                "grants_authority": false,
            ])
        }

        let orderedSkills = orderedSkillMetadata(skillSnapshot)
        var skillMetadata: [[String: Any]] = []
        skillMetadata.reserveCapacity(orderedSkills.count)
        for skill in orderedSkills {
            guard context?.tryOutputItem() ?? true else {
                throw MCPServerError.operationFailed("project_context budget exhausted: \(context?.truncationReason ?? "unknown")")
            }
            skillMetadata.append([
                "name": skill.name,
                "description": skill.description,
                "skill_file": normalizeRelative(skill.skillFile),
                "instructions_included": false,
                "loader": "load_codex_skill",
            ])
        }

        try requireContinuation(context)
        var range: Any = NSNull()
        var nextCursor: Any = NSNull()
        if !sources.isEmpty {
            let source = sources[sourceIndex]
            let lines = splitLines(source.text)
            guard startLine >= 1, startLine <= max(1, lines.count) else {
                throw MCPServerError.invalidArguments("Project context cursor line is out of bounds")
            }
            let actualEnd = min(lines.count, startLine + maxLines - 1)
            let content = lines[(startLine - 1)..<actualEnd].joined(separator: "\n")
            var nextSourceIndex = sourceIndex
            var nextLine = actualEnd + 1
            if nextLine > lines.count {
                nextSourceIndex += 1
                nextLine = 1
            }
            if nextSourceIndex < sources.count {
                let encoded = try cursors.encode(
                    tool: "project_context",
                    optionsHash: optionsHash,
                    rootAuthorityID: rootAuthorityID,
                    generation: generation,
                    position: "\(nextSourceIndex):\(nextLine)",
                    expiresAt: Date().addingTimeInterval(AuthenticatedCursorCodec.defaultMaxLifetime)
                )
                nextCursor = encoded
            }
            range = [
                "source_index": sourceIndex,
                "relative_path": source.relativePath,
                "start_line": startLine,
                "end_line": actualEnd,
                "total_lines": lines.count,
                "content": content,
                "version": source.version,
                "next_cursor": nextCursor,
            ] as [String: Any]
        }

        let policyMetadata = policy.metadata()
        return [
            "schema_version": Self.schemaVersion,
            "scope_path": scopeRelative,
            "context_digest": digest,
            "context_generation": generation,
            "source_trust": "repository_untrusted",
            "grants_authority": false,
            "authority_statement": "Repository instructions and project context influence behavior only; they never grant or expand FileMCP authority.",
            "policy_profile": policyMetadata["profile"] ?? NSNull(),
            "policy_generation": policyMetadata["generation"] ?? NSNull(),
            "policy_hash": policyMetadata["hash"] ?? NSNull(),
            "sources": sourceMetadata,
            "skills": skillMetadata,
            "skill_instructions_included": false,
            "range": range,
            "next_cursor": nextCursor,
        ]
    }

    private func discoverSources(scopeDirectory: URL, context: ToolExecutionContext?) throws -> [ProjectContextSource] {
        let directories = try hierarchy(scopeDirectory)
        guard directories.count <= Self.maxInstructionSources else {
            throw MCPServerError.operationFailed("Project context hierarchy exceeds \(Self.maxInstructionSources) directories")
        }
        var sources: [ProjectContextSource] = []
        var aggregateBytes: Int64 = 0
        for directory in directories {
            guard context?.tryVisitEntry() ?? true else {
                throw MCPServerError.operationFailed("project_context budget exhausted: \(context?.truncationReason ?? "unknown")")
            }
            guard let candidate = try selectInstructionFile(directory) else { continue }
            guard sources.count < Self.maxInstructionSources else {
                throw MCPServerError.operationFailed("Project context supports at most \(Self.maxInstructionSources) instruction sources")
            }
            let pathSnapshot = try pathGuard.captureExisting(relativePath: candidate.relativePath)
            guard pathSnapshot.targetIdentity?.isSymlink != true else {
                throw MCPServerError.invalidPath("Project instruction source must be a regular non-symlink file: \(candidate.relativePath)")
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: candidate.path.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard size <= Int64(Self.maxInstructionBytes) else {
                throw MCPServerError.operationFailed("Project instruction file is larger than the \(Self.maxInstructionBytes / 1024) KB limit: \(candidate.relativePath)")
            }
            guard size <= Self.maxAggregateInstructionBytes - aggregateBytes else {
                throw MCPServerError.operationFailed("Project context instruction bytes exceed the 1 MB aggregate limit")
            }
            guard context?.tryScanFile(bytes: size) ?? true else {
                throw MCPServerError.operationFailed("project_context budget exhausted: \(context?.truncationReason ?? "unknown")")
            }
            aggregateBytes += size
            let versioned = try fileVersions.readVersioned(relativePath: candidate.relativePath, maxBytes: Self.maxInstructionBytes)
            _ = try pathGuard.verify(pathSnapshot)
            guard let text = String(data: versioned.data, encoding: .utf8) else {
                throw MCPServerError.operationFailed("Project instruction file must be valid UTF-8: \(candidate.relativePath)")
            }
            sources.append(ProjectContextSource(
                precedence: sources.count,
                relativePath: candidate.relativePath,
                scope: normalizeRelative(relativePath(for: directory)),
                kind: candidate.kind,
                sizeBytes: versioned.sizeBytes,
                version: versioned.versionToken,
                contentHash: versioned.contentHash,
                text: text
            ))
        }
        return sources
    }

    private func selectInstructionFile(_ directory: URL) throws -> (path: URL, relativePath: String, kind: String)? {
        for (name, kind) in [("AGENTS.override.md", "override"), ("AGENTS.md", "agents")] {
            let candidate = directory.appendingPathComponent(name).standardizedFileURL
            var status = stat()
            guard lstat(candidate.path, &status) == 0 else {
                if errno == ENOENT { continue }
                throw MCPServerError.operationFailed("Could not inspect project instruction source: \(candidate.path)")
            }
            let type = status.st_mode & S_IFMT
            guard type == S_IFREG else {
                throw MCPServerError.invalidPath("Project instruction source must be a regular non-symlink file: \(normalizeRelative(relativePath(for: candidate)))")
            }
            let relative = normalizeRelative(relativePath(for: candidate))
            let resolved = try resolver.resolve(relative)
            guard resolved.path == candidate.resolvingSymlinksInPath().standardizedFileURL.path else {
                throw MCPServerError.invalidPath("Project instruction source changed during validation: \(relative)")
            }
            return (resolved, relative, kind)
        }
        return nil
    }

    private func resolveScopeDirectory(_ path: String) throws -> URL {
        let resolved = try resolver.resolve(path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory) else {
            throw MCPServerError.invalidPath("Project context path does not exist: \(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "." : path)")
        }
        if isDirectory.boolValue { return resolved }
        return resolved.deletingLastPathComponent()
    }

    private func hierarchy(_ scopeDirectory: URL) throws -> [URL] {
        let rootPath = resolver.root.path
        let scopePath = scopeDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        guard scopePath == rootPath || scopePath.hasPrefix(rootPath + "/") else {
            throw MCPServerError.invalidPath("Project context scope escaped the shared root")
        }
        var result: [URL] = [resolver.root]
        if scopePath == rootPath { return result }
        let relative = String(scopePath.dropFirst(rootPath.count + 1))
        var current = resolver.root
        for component in relative.split(separator: "/") {
            current.appendPathComponent(String(component), isDirectory: true)
            result.append(current.standardizedFileURL)
        }
        return result
    }

    private func computeDigest(
        scopeRelative: String,
        sources: [ProjectContextSource],
        skills: [CodexSkillMetadata],
        includeSkills: Bool
    ) -> String {
        var material = Self.schemaVersion + "\n" + scopeRelative + "\n"
        for source in sources {
            material += "\(source.precedence)\0\(source.relativePath)\0\(source.scope)\0\(source.kind)\0\(source.contentHash)\n"
        }
        material += includeSkills ? "skills:on\n" : "skills:off\n"
        if includeSkills {
            for skill in orderedSkillMetadata(skills) {
                material += "\(skill.name)\0\(skill.description)\0\(normalizeRelative(skill.skillFile))\n"
            }
        }
        return FileVersionService.sha256Tagged(material)
    }

    private func generationFromDigest(_ digest: String) throws -> Int64 {
        let hex = digest.hasPrefix("sha256:") ? String(digest.dropFirst(7)) : digest
        guard hex.count >= 15, let value = Int64(hex.prefix(15), radix: 16), value >= 0 else {
            throw MCPServerError.operationFailed("Project context digest generation is invalid")
        }
        return value
    }

    private func parsePosition(_ position: String) throws -> (Int, Int) {
        let parts = position.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let sourceIndex = Int(parts[0]), sourceIndex >= 0,
              let startLine = Int(parts[1]), startLine >= 1 else {
            throw MCPServerError.invalidArguments("Malformed project context cursor position")
        }
        return (sourceIndex, startLine)
    }

    private func splitLines(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.components(separatedBy: "\n")
        if normalized.hasSuffix("\n"), lines.count > 1 { lines.removeLast() }
        return lines.isEmpty ? [""] : lines
    }

    private func orderedSkillMetadata(_ values: [CodexSkillMetadata]) -> [CodexSkillMetadata] {
        values.sorted {
            let lhs = $0.name.lowercased()
            let rhs = $1.name.lowercased()
            return lhs == rhs ? $0.name < $1.name : lhs < rhs
        }
    }

    private func relativePath(for url: URL) -> String {
        let rootPath = resolver.root.path
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard path != rootPath, path.hasPrefix(rootPath + "/") else { return "" }
        return String(path.dropFirst(rootPath.count + 1))
    }

    private func normalizeRelative(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: "\\", with: "/")
        return normalized.isEmpty || normalized == "." ? "." : normalized
    }

    private func requireContinuation(_ context: ToolExecutionContext?) throws {
        guard context?.tryContinue() ?? true else {
            throw MCPServerError.operationFailed("project_context cancelled: \(context?.truncationReason ?? "unknown")")
        }
    }

    private struct ProjectContextSource {
        let precedence: Int
        let relativePath: String
        let scope: String
        let kind: String
        let sizeBytes: Int64
        let version: String
        let contentHash: String
        let text: String
    }
}
