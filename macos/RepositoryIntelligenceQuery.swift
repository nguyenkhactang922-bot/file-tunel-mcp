import Foundation

struct RepositoryIntelligenceQueryOptions {
    var repoMapSpillThresholdBytes: Int = 256 * 1024
    var artifactTTL: TimeInterval = 24 * 60 * 60
    var stageForTests: ((String) -> Void)?

    func validate() throws {
        guard (1024...(8 * 1024 * 1024)).contains(repoMapSpillThresholdBytes) else {
            throw MCPServerError.invalidArguments("Repo map spill threshold must be 1 KiB..8 MiB")
        }
        guard artifactTTL > 0, artifactTTL <= 7 * 24 * 60 * 60 else {
            throw MCPServerError.invalidArguments("Repository map artifact TTL must be positive and <= 7 days")
        }
    }
}

extension LocalTools {
    func repoMap(
        repoPath: String,
        cursor: String,
        maxItems: Int,
        allowContentRef: Bool,
        context: ToolExecutionContext?
    ) throws -> [String: Any] {
        guard (1...500).contains(maxItems) else {
            throw MCPServerError.invalidArguments("max_items must be 1..500")
        }

        let snapshot = try captureRepositoryIntelligence(repoPath: repoPath, context: context)
        try ensureQuerySnapshotUsable(snapshot)
        let sourceStateID = try queryRequiredString(snapshot, "source_state_id")
        let files = try snapshotFiles(snapshot).sorted {
            try queryRequiredString($0, "path") < queryRequiredString($1, "path")
        }

        let optionsHash = AuthenticatedCursorCodec.stableHash([
            "repo-map-v1",
            normalizeQueryRepoPath(repoPath),
            String(maxItems),
        ].joined(separator: "\n"))
        let generation = try queryGeneration(sourceStateID)
        let start = try decodePagePosition(
            cursor,
            tool: "repo_map",
            optionsHash: optionsHash,
            generation: generation
        )
        guard start <= files.count else {
            throw MCPServerError.invalidArguments("Cursor position is outside the current result set")
        }

        var items: [[String: Any]] = []
        var index = start
        while index < files.count && items.count < maxItems {
            if let context, !context.tryOutputItem() { break }
            let file = files[index]
            let path = try queryRequiredString(file, "path")
            let symbols = file["symbols"] as? [[String: Any]] ?? []
            let imports = file["imports"] as? [[String: Any]] ?? []
            items.append([
                "path": path,
                "language": file["language"] ?? NSNull(),
                "size_bytes": file["size_bytes"] ?? NSNull(),
                "supported_language": file["supported_language"] ?? false,
                "symbol_count": symbols.count,
                "import_count": imports.count,
                "relation_count": try countRelations(snapshot, path: path),
            ])
            index += 1
        }

        let budgetTruncated = context?.truncated == true
        let nextCursor: String?
        if index < files.count && !budgetTruncated {
            nextCursor = try encodePagePosition(
                tool: "repo_map",
                optionsHash: optionsHash,
                generation: generation,
                position: index
            )
        } else {
            nextCursor = nil
        }

        repositoryQueryOptions.stageForTests?("before_freshness_recheck")
        try requireQueryFresh(repoPath: repoPath, expectedSourceStateID: sourceStateID)

        var contentRef: String?
        var blobID: String?
        var expiresEpochMs: Int64?
        var artifactState = "not_requested"
        if allowContentRef {
            let fullMap = try buildFullMapArtifact(snapshot)
            let bytes = try JSONSerialization.data(withJSONObject: fullMap, options: [.sortedKeys])
            if bytes.count >= repositoryQueryOptions.repoMapSpillThresholdBytes {
                artifactState = "unavailable"
                do {
                    let artifacts = try repositoryQueryArtifactFactory()
                    let descriptor = try artifacts.put(
                        data: bytes,
                        workspaceAuthorityID: repositoryQueryWorkspaceAuthorityID,
                        contentClass: ArtifactContentClasses.toolOutput,
                        mediaType: "application/vnd.filemcp.repository-map+json",
                        ttl: repositoryQueryOptions.artifactTTL
                    )
                    contentRef = descriptor.contentRef
                    blobID = descriptor.blobID
                    expiresEpochMs = descriptor.expiresEpochMs
                    artifactState = "available"

                    do {
                        repositoryQueryOptions.stageForTests?("after_artifact_publish")
                        try requireQueryFresh(repoPath: repoPath, expectedSourceStateID: sourceStateID)
                    } catch {
                        _ = try? artifacts.delete(
                            contentRef: descriptor.contentRef,
                            workspaceAuthorityID: repositoryQueryWorkspaceAuthorityID,
                            contentClassAllowed: { $0 == ArtifactContentClasses.toolOutput }
                        )
                        throw error
                    }
                } catch let error as ArtifactContentStoreError {
                    _ = error
                    artifactState = "unavailable"
                    contentRef = nil
                    blobID = nil
                    expiresEpochMs = nil
                }
            } else {
                artifactState = "below_threshold"
            }
        }

        return queryEnvelope(snapshot, query: [
            "query_kind": "repo_map",
            "total_items": files.count,
            "start_index": start,
            "returned_count": items.count,
            "items": items,
            "next_cursor": nextCursor ?? NSNull(),
            "partial": index < files.count || budgetTruncated,
            "truncated": budgetTruncated,
            "truncation_reason": context?.truncationReason ?? "none",
            "artifact_state": artifactState,
            "content_ref": contentRef ?? NSNull(),
            "blob_id": blobID ?? NSNull(),
            "expires_epoch_ms": expiresEpochMs.map(NSNumber.init(value:)) ?? NSNull(),
        ])
    }

    func symbolSearch(
        repoPath: String,
        query: String,
        kind: String,
        caseSensitive: Bool,
        cursor: String,
        maxResults: Int,
        context: ToolExecutionContext?
    ) throws -> [String: Any] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw MCPServerError.invalidArguments("query must not be empty")
        }
        guard trimmedQuery.count <= 512 else {
            throw MCPServerError.invalidArguments("query is too long")
        }
        guard (1...200).contains(maxResults) else {
            throw MCPServerError.invalidArguments("max_results must be 1..200")
        }
        let kindFilter = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        guard kindFilter.count <= 64 else {
            throw MCPServerError.invalidArguments("kind is too long")
        }

        let snapshot = try captureRepositoryIntelligence(repoPath: repoPath, context: context)
        try ensureQuerySnapshotUsable(snapshot)
        let sourceStateID = try queryRequiredString(snapshot, "source_state_id")

        struct Match {
            let item: [String: Any]
            let score: Double
            let exact: Bool
            let name: String
            let path: String
            let line: Int
        }
        var supported = false
        var matches: [Match] = []

        for file in try snapshotFiles(snapshot) {
            if (file["supported_language"] as? Bool) == true { supported = true }
            guard let symbols = file["symbols"] as? [[String: Any]] else { continue }
            let path = try queryRequiredString(file, "path")
            for symbol in symbols {
                let name = try queryRequiredString(symbol, "name")
                let symbolKind = try queryRequiredString(symbol, "kind")
                if !kindFilter.isEmpty && symbolKind.caseInsensitiveCompare(kindFilter) != .orderedSame {
                    continue
                }
                let score = queryMatchScore(name, trimmedQuery, caseSensitive: caseSensitive)
                if score <= 0 { continue }
                let line = (symbol["line"] as? NSNumber)?.intValue ?? 0
                matches.append(Match(
                    item: [
                        "path": path,
                        "name": name,
                        "kind": symbolKind,
                        "line": line,
                        "score": score,
                    ],
                    score: score,
                    exact: score >= 1.0,
                    name: name,
                    path: path,
                    line: line
                ))
            }
        }

        let ordered = matches.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.name != $1.name { return $0.name < $1.name }
            if $0.path != $1.path { return $0.path < $1.path }
            return $0.line < $1.line
        }
        let exactCount = ordered.filter(\.exact).count

        let optionsHash = AuthenticatedCursorCodec.stableHash([
            "symbol-search-v1",
            normalizeQueryRepoPath(repoPath),
            trimmedQuery,
            kindFilter,
            caseSensitive ? "case:on" : "case:off",
            String(maxResults),
        ].joined(separator: "\n"))
        let generation = try queryGeneration(sourceStateID)
        let start = try decodePagePosition(
            cursor,
            tool: "symbol_search",
            optionsHash: optionsHash,
            generation: generation
        )
        let values = ordered.map(\.item)
        let page = try pageItems(values, start: start, maxItems: maxResults, context: context)

        let budgetTruncated = context?.truncated == true
        let nextCursor = page.nextIndex < values.count && !budgetTruncated
            ? try encodePagePosition(
                tool: "symbol_search",
                optionsHash: optionsHash,
                generation: generation,
                position: page.nextIndex
            )
            : nil

        repositoryQueryOptions.stageForTests?("before_freshness_recheck")
        try requireQueryFresh(repoPath: repoPath, expectedSourceStateID: sourceStateID)

        return queryEnvelope(snapshot, query: [
            "query_kind": "symbol_search",
            "query": trimmedQuery,
            "kind_filter": kindFilter,
            "symbol_support": supported,
            "ambiguous": exactCount > 1,
            "exact_match_count": exactCount,
            "total_results": values.count,
            "returned_count": page.items.count,
            "results": page.items,
            "next_cursor": nextCursor ?? NSNull(),
            "partial": page.nextIndex < values.count || budgetTruncated,
            "truncated": budgetTruncated,
            "truncation_reason": context?.truncationReason ?? "none",
        ])
    }

    func relatedFiles(
        repoPath: String,
        relativePath: String,
        minScore: Double,
        cursor: String,
        maxResults: Int,
        context: ToolExecutionContext?
    ) throws -> [String: Any] {
        let normalizedPath = try normalizeQueryRelativePath(relativePath)
        guard minScore.isFinite, minScore >= 0, minScore <= 1 else {
            throw MCPServerError.invalidArguments("min_score must be between 0 and 1")
        }
        guard (1...200).contains(maxResults) else {
            throw MCPServerError.invalidArguments("max_results must be 1..200")
        }

        let snapshot = try captureRepositoryIntelligence(repoPath: repoPath, context: context)
        try ensureQuerySnapshotUsable(snapshot)
        let sourceStateID = try queryRequiredString(snapshot, "source_state_id")
        let paths = Set(try snapshotFiles(snapshot).map { try queryRequiredString($0, "path") })
        guard paths.contains(normalizedPath) else {
            throw MCPServerError.operationFailed("related_files path is not present in the current repository intelligence generation")
        }

        struct RelationItem {
            let item: [String: Any]
            let score: Double
            let path: String
            let kind: String
            let direction: String
        }
        var related: [RelationItem] = []
        if let relations = snapshot["relations"] as? [[String: Any]] {
            for relation in relations {
                let source = try queryRequiredString(relation, "source")
                let target = try queryRequiredString(relation, "target")
                let score = (relation["score"] as? NSNumber)?.doubleValue ?? 0
                if score < minScore { continue }

                let path: String
                let direction: String
                if source == normalizedPath {
                    path = target
                    direction = "outgoing"
                } else if target == normalizedPath {
                    path = source
                    direction = "incoming"
                } else {
                    continue
                }
                let relationKind = try queryRequiredString(relation, "kind")
                related.append(RelationItem(
                    item: [
                        "path": path,
                        "direction": direction,
                        "kind": relationKind,
                        "score": score,
                        "rank": relation["rank"] ?? NSNull(),
                    ],
                    score: score,
                    path: path,
                    kind: relationKind,
                    direction: direction
                ))
            }
        }

        let ordered = related.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.kind != $1.kind { return $0.kind < $1.kind }
            return $0.direction < $1.direction
        }.map(\.item)

        let optionsHash = AuthenticatedCursorCodec.stableHash([
            "related-files-v1",
            normalizeQueryRepoPath(repoPath),
            normalizedPath,
            String(format: "%.17g", minScore),
            String(maxResults),
        ].joined(separator: "\n"))
        let generation = try queryGeneration(sourceStateID)
        let start = try decodePagePosition(
            cursor,
            tool: "related_files",
            optionsHash: optionsHash,
            generation: generation
        )
        let page = try pageItems(ordered, start: start, maxItems: maxResults, context: context)

        let budgetTruncated = context?.truncated == true
        let nextCursor = page.nextIndex < ordered.count && !budgetTruncated
            ? try encodePagePosition(
                tool: "related_files",
                optionsHash: optionsHash,
                generation: generation,
                position: page.nextIndex
            )
            : nil

        repositoryQueryOptions.stageForTests?("before_freshness_recheck")
        try requireQueryFresh(repoPath: repoPath, expectedSourceStateID: sourceStateID)

        return queryEnvelope(snapshot, query: [
            "query_kind": "related_files",
            "relative_path": normalizedPath,
            "min_score": minScore,
            "total_results": ordered.count,
            "returned_count": page.items.count,
            "results": page.items,
            "next_cursor": nextCursor ?? NSNull(),
            "partial": page.nextIndex < ordered.count || budgetTruncated,
            "truncated": budgetTruncated,
            "truncation_reason": context?.truncationReason ?? "none",
        ])
    }

    private func queryEnvelope(_ snapshot: [String: Any], query: [String: Any]) -> [String: Any] {
        var output = query
        output["schema_version"] = "1.0.0"
        output["provider_id"] = snapshot["provider_id"] ?? NSNull()
        output["provider_version"] = snapshot["provider_version"] ?? NSNull()
        output["completeness"] = snapshot["completeness"] ?? NSNull()
        output["parser_profile_hash"] = snapshot["parser_profile_hash"] ?? NSNull()
        output["source_state_id"] = snapshot["source_state_id"] ?? NSNull()
        output["grants_authority"] = false
        output["raw_source_persisted"] = false
        output["generation_truncated"] = snapshot["truncated"] ?? NSNull()
        output["generation_truncation_reason"] = snapshot["truncation_reason"] ?? NSNull()
        return output
    }

    private func buildFullMapArtifact(_ snapshot: [String: Any]) throws -> [String: Any] {
        let files = try snapshotFiles(snapshot).sorted {
            try queryRequiredString($0, "path") < queryRequiredString($1, "path")
        }
        return [
            "schema_version": "1.0.0",
            "kind": "repository_map",
            "provider_id": snapshot["provider_id"] ?? NSNull(),
            "provider_version": snapshot["provider_version"] ?? NSNull(),
            "completeness": snapshot["completeness"] ?? NSNull(),
            "parser_profile_hash": snapshot["parser_profile_hash"] ?? NSNull(),
            "source_state_id": snapshot["source_state_id"] ?? NSNull(),
            "grants_authority": false,
            "raw_source_persisted": false,
            "files": files,
            "relations": snapshot["relations"] ?? [],
        ]
    }

    private func requireQueryFresh(repoPath: String, expectedSourceStateID: String) throws {
        let current = try captureSourceStateRef(repoPath: repoPath)
        guard let currentID = current["source_state_id"] as? String, !currentID.isEmpty else {
            throw MCPServerError.operationFailed("Repository intelligence query SourceStateRef is unavailable")
        }
        guard currentID == expectedSourceStateID else {
            throw MCPServerError.operationFailed("Repository intelligence query generation became stale")
        }
    }

    private func decodePagePosition(
        _ cursor: String,
        tool: String,
        optionsHash: String,
        generation: Int64
    ) throws -> Int {
        if cursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return 0 }
        let position = try repositoryQueryCursors.decode(
            cursor,
            expectedTool: tool,
            expectedOptionsHash: optionsHash,
            expectedRootAuthorityID: repositoryQueryWorkspaceAuthorityID,
            expectedGeneration: generation,
            now: Date()
        )
        guard let value = Int(position), value >= 0 else {
            throw MCPServerError.invalidArguments("Invalid cursor position")
        }
        return value
    }

    private func encodePagePosition(
        tool: String,
        optionsHash: String,
        generation: Int64,
        position: Int
    ) throws -> String {
        try repositoryQueryCursors.encode(
            tool: tool,
            optionsHash: optionsHash,
            rootAuthorityID: repositoryQueryWorkspaceAuthorityID,
            generation: generation,
            position: String(position),
            expiresAt: Date().addingTimeInterval(AuthenticatedCursorCodec.defaultMaxLifetime)
        )
    }

    private func queryGeneration(_ sourceStateID: String) throws -> Int64 {
        let hash = AuthenticatedCursorCodec.stableHash(sourceStateID)
        guard hash.count >= 16, let value = UInt64(hash.prefix(16), radix: 16) else {
            throw MCPServerError.operationFailed("Repository query generation hash is invalid")
        }
        return Int64(value & 0x7fff_ffff_ffff_ffff)
    }

    private func pageItems(
        _ values: [[String: Any]],
        start: Int,
        maxItems: Int,
        context: ToolExecutionContext?
    ) throws -> (items: [[String: Any]], nextIndex: Int) {
        guard start <= values.count else {
            throw MCPServerError.invalidArguments("Cursor position is outside the current result set")
        }
        var output: [[String: Any]] = []
        var index = start
        while index < values.count && output.count < maxItems {
            if let context, !context.tryOutputItem() { break }
            output.append(values[index])
            index += 1
        }
        return (output, index)
    }

    private func queryMatchScore(_ value: String, _ query: String, caseSensitive: Bool) -> Double {
        if caseSensitive {
            if value == query { return 1.0 }
            if value.hasPrefix(query) { return 0.75 }
            if value.contains(query) { return 0.5 }
            return 0
        }
        let lhs = value.lowercased()
        let rhs = query.lowercased()
        if lhs == rhs { return 1.0 }
        if lhs.hasPrefix(rhs) { return 0.75 }
        if lhs.contains(rhs) { return 0.5 }
        return 0
    }

    private func countRelations(_ snapshot: [String: Any], path: String) throws -> Int {
        guard let relations = snapshot["relations"] as? [[String: Any]] else { return 0 }
        var count = 0
        for relation in relations {
            let source = try queryRequiredString(relation, "source")
            let target = try queryRequiredString(relation, "target")
            if source == path || target == path { count += 1 }
        }
        return count
    }

    private func snapshotFiles(_ snapshot: [String: Any]) throws -> [[String: Any]] {
        snapshot["files"] as? [[String: Any]] ?? []
    }

    private func queryRequiredString(_ value: [String: Any], _ key: String) throws -> String {
        guard let result = value[key] as? String else {
            throw MCPServerError.operationFailed("Repository intelligence metadata missing \(key)")
        }
        return result
    }

    private func ensureQuerySnapshotUsable(_ snapshot: [String: Any]) throws {
        guard let sourceStateID = snapshot["source_state_id"] as? String, !sourceStateID.isEmpty else {
            throw MCPServerError.operationFailed("Repository intelligence generation has no SourceStateRef")
        }
        guard (snapshot["grants_authority"] as? Bool) == false else {
            throw MCPServerError.operationFailed("Repository intelligence authority invariant failed")
        }
    }

    private func normalizeQueryRepoPath(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func normalizeQueryRelativePath(_ value: String) throws -> String {
        let normalized = value.replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = Array(normalized.utf8)
        let windowsRooted = bytes.count >= 3 &&
            ((bytes[0] >= 65 && bytes[0] <= 90) || (bytes[0] >= 97 && bytes[0] <= 122)) &&
            bytes[1] == 58 && bytes[2] == 47
        guard !normalized.isEmpty, !normalized.hasPrefix("/"), !windowsRooted else {
            throw MCPServerError.invalidPath("relative_path must be a repository-relative path")
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw MCPServerError.invalidPath("relative_path contains an invalid path segment")
        }
        return parts.joined(separator: "/")
    }
}
