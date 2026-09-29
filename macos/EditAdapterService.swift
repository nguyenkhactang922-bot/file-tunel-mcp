import Foundation

enum EditAdapterServiceError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self { case let .invalid(message): return message }
    }
}

struct EditAdapterCompilation {
    let edits: [[String: Any]]
    let matchCount: Int
    let hunkCount: Int
}

final class EditAdapterService {
    private static let maxFileBytes = 5_000_000
    private static let hunkRegex = try! NSRegularExpression(
        pattern: #"^@@ -([0-9]+)(?:,([0-9]+))? \+([0-9]+)(?:,([0-9]+))? @@(?: .*)?$"#,
        options: []
    )

    private let versions: FileVersionService

    init(versions: FileVersionService) {
        self.versions = versions
    }

    func compileSearchReplace(
        relativePath: String,
        expectedVersion: String,
        search: String,
        replacement: String,
        context: ToolExecutionContext?
    ) throws -> EditAdapterCompilation {
        guard !expectedVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EditAdapterServiceError.invalid("expected_version must not be empty")
        }
        guard !search.isEmpty else {
            throw EditAdapterServiceError.invalid("search must not be empty")
        }
        try requireContinue(context, message: "apply_search_replace cancelled before compile")

        let source = try versions.readExpectedVersioned(
            relativePath: relativePath,
            token: expectedVersion,
            maxBytes: Self.maxFileBytes
        )
        if let context, !context.tryScanFile(bytes: source.sizeBytes) {
            throw EditAdapterServiceError.invalid("apply_search_replace budget exhausted while reading source")
        }

        let content = contentWithoutBom(source.data)
        guard String(data: content, encoding: .utf8) != nil else {
            throw EditAdapterServiceError.invalid("apply_search_replace requires valid UTF-8 source text")
        }
        let haystack = [UInt8](content)
        let needle = [UInt8](search.utf8)
        let matches = try findAll(haystack: haystack, needle: needle, context: context)
        guard matches.count == 1 else {
            if matches.isEmpty {
                throw EditAdapterServiceError.invalid("apply_search_replace search text matched zero locations")
            }
            throw EditAdapterServiceError.invalid("apply_search_replace search text is ambiguous: matched \(matches.count) locations")
        }

        let start = matches[0]
        return EditAdapterCompilation(
            edits: [[
                "start_byte": start,
                "end_byte": start + needle.count,
                "replacement": replacement,
            ]],
            matchCount: 1,
            hunkCount: 0
        )
    }

    func compileUnifiedDiff(
        relativePath: String,
        expectedVersion: String,
        unifiedDiff: String,
        context: ToolExecutionContext?
    ) throws -> EditAdapterCompilation {
        guard !expectedVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EditAdapterServiceError.invalid("expected_version must not be empty")
        }
        guard !unifiedDiff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EditAdapterServiceError.invalid("unified_diff must not be empty")
        }
        try requireContinue(context, message: "apply_unified_diff cancelled before compile")

        let source = try versions.readExpectedVersioned(
            relativePath: relativePath,
            token: expectedVersion,
            maxBytes: Self.maxFileBytes
        )
        if let context, !context.tryScanFile(bytes: source.sizeBytes) {
            throw EditAdapterServiceError.invalid("apply_unified_diff budget exhausted while reading source")
        }

        let content = contentWithoutBom(source.data)
        guard String(data: content, encoding: .utf8) != nil else {
            throw EditAdapterServiceError.invalid("apply_unified_diff requires valid UTF-8 source text")
        }
        let sourceLines = try buildLines(content)
        let normalized = unifiedDiff
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let diff = normalized.components(separatedBy: "\n")

        let headerIndex = try findHeader(diff, context: context)
        guard headerIndex >= 0,
              headerIndex + 1 < diff.count,
              diff[headerIndex + 1].hasPrefix("+++ ") else {
            throw EditAdapterServiceError.invalid("apply_unified_diff requires ---/+++ file headers")
        }
        try validateHeaderPath(String(diff[headerIndex].dropFirst(4)), relativePath: relativePath, side: "old")
        try validateHeaderPath(String(diff[headerIndex + 1].dropFirst(4)), relativePath: relativePath, side: "new")

        var edits: [CompiledHunk] = []
        var index = headerIndex + 2
        var hunkIndex = 0

        while index < diff.count {
            try requireContinue(context, message: "apply_unified_diff cancelled during compile")
            if diff[index].isEmpty {
                index += 1
                continue
            }
            if diff[index].hasPrefix("--- ") || diff[index].hasPrefix("+++ ") {
                throw EditAdapterServiceError.invalid("apply_unified_diff supports exactly one file")
            }
            guard diff[index].hasPrefix("@@ ") else {
                throw EditAdapterServiceError.invalid("apply_unified_diff malformed unified diff near line \(index + 1)")
            }

            let header = try parseHunkHeader(diff[index])
            try validateHunkBounds(
                oldStart: header.oldStart,
                oldCount: header.oldCount,
                newStart: header.newStart,
                newCount: header.newCount,
                lineCount: sourceLines.count
            )
            index += 1

            var sourceCursor = header.oldCount == 0 ? header.oldStart : header.oldStart - 1
            var consumedOld = 0
            var producedNew = 0
            var replacementLines: [String] = []
            var previousPrefix: Character?
            var newNoNewline = false
            var sawBody = false

            while index < diff.count && !diff[index].hasPrefix("@@ ") {
                try requireContinue(context, message: "apply_unified_diff cancelled during hunk compile")
                let line = diff[index]
                if line.hasPrefix("--- ") || line.hasPrefix("+++ ") {
                    throw EditAdapterServiceError.invalid("apply_unified_diff supports exactly one file")
                }
                if line == "\\ No newline at end of file" {
                    guard sawBody else {
                        throw EditAdapterServiceError.invalid("apply_unified_diff newline marker has no preceding hunk line")
                    }
                    if previousPrefix == "+" || previousPrefix == " " {
                        newNoNewline = true
                    }
                    index += 1
                    continue
                }
                if line.isEmpty { break }

                guard let prefix = line.first, prefix == " " || prefix == "+" || prefix == "-" else {
                    throw EditAdapterServiceError.invalid("apply_unified_diff malformed hunk line near line \(index + 1)")
                }
                let text = String(line.dropFirst())
                sawBody = true
                previousPrefix = prefix

                if prefix == " " || prefix == "-" {
                    guard sourceCursor >= 0, sourceCursor < sourceLines.count else {
                        throw EditAdapterServiceError.invalid("apply_unified_diff hunk extends beyond source file")
                    }
                    guard sourceLines[sourceCursor].text == text else {
                        throw EditAdapterServiceError.invalid("apply_unified_diff hunk context does not match source at line \(sourceCursor + 1)")
                    }
                    sourceCursor += 1
                    consumedOld += 1
                }
                if prefix == " " || prefix == "+" {
                    replacementLines.append(text)
                    producedNew += 1
                }
                if consumedOld > header.oldCount || producedNew > header.newCount {
                    throw EditAdapterServiceError.invalid("apply_unified_diff hunk body exceeds declared line counts")
                }
                index += 1
            }

            if !sawBody && (header.oldCount != 0 || header.newCount != 0) {
                throw EditAdapterServiceError.invalid("apply_unified_diff hunk has no body")
            }
            guard consumedOld == header.oldCount, producedNew == header.newCount else {
                throw EditAdapterServiceError.invalid(
                    "apply_unified_diff hunk line counts do not match header (old \(consumedOld)/\(header.oldCount), new \(producedNew)/\(header.newCount))"
                )
            }

            let range = try hunkByteRange(
                lines: sourceLines,
                oldStart: header.oldStart,
                oldCount: header.oldCount
            )
            let replacement = replacementLines.isEmpty
                ? ""
                : replacementLines.joined(separator: "\n") + (newNoNewline ? "" : "\n")
            edits.append(CompiledHunk(
                start: range.0,
                end: range.1,
                replacement: replacement,
                hunkIndex: hunkIndex
            ))
            hunkIndex += 1
        }

        guard !edits.isEmpty else {
            throw EditAdapterServiceError.invalid("apply_unified_diff contains no hunks")
        }
        guard edits.count <= 1024 else {
            throw EditAdapterServiceError.invalid("apply_unified_diff supports at most 1024 hunks")
        }

        let ordered = edits.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.end != $1.end { return $0.end < $1.end }
            return $0.hunkIndex < $1.hunkIndex
        }
        if ordered.count > 1 {
            for i in 1..<ordered.count {
                let previous = ordered[i - 1]
                let current = ordered[i]
                if current.start < previous.end || current.start == previous.start {
                    throw EditAdapterServiceError.invalid("apply_unified_diff contains overlapping hunks")
                }
            }
        }

        let json = edits.map {
            [
                "start_byte": $0.start,
                "end_byte": $0.end,
                "replacement": $0.replacement,
            ] as [String: Any]
        }
        return EditAdapterCompilation(edits: json, matchCount: 0, hunkCount: edits.count)
    }

    private func contentWithoutBom(_ raw: Data) -> Data {
        if raw.count >= 3, raw[0] == 0xEF, raw[1] == 0xBB, raw[2] == 0xBF {
            return Data(raw.dropFirst(3))
        }
        return raw
    }

    private func findAll(
        haystack: [UInt8],
        needle: [UInt8],
        context: ToolExecutionContext?
    ) throws -> [Int] {
        if needle.count > haystack.count { return [] }
        var matches: [Int] = []
        let last = haystack.count - needle.count
        if last < 0 { return [] }

        for index in 0...last {
            if (index & 0x3FFF) == 0 {
                try requireContinue(context, message: "apply_search_replace cancelled during compile")
            }
            if Array(haystack[index..<(index + needle.count)]) == needle {
                matches.append(index)
            }
        }
        return matches
    }

    private func buildLines(_ content: Data) throws -> [SourceLine] {
        let bytes = [UInt8](content)
        var result: [SourceLine] = []
        var start = 0
        var index = 0

        while index < bytes.count {
            if bytes[index] != 0x0D && bytes[index] != 0x0A {
                index += 1
                continue
            }
            let textEnd = index
            var end = index + 1
            if bytes[index] == 0x0D, end < bytes.count, bytes[end] == 0x0A {
                end += 1
            }
            guard let text = String(bytes: bytes[start..<textEnd], encoding: .utf8) else {
                throw EditAdapterServiceError.invalid("apply_unified_diff requires valid UTF-8 source text")
            }
            result.append(SourceLine(text: text, startByte: start, endByte: end))
            start = end
            index = end
        }

        if start < bytes.count {
            guard let text = String(bytes: bytes[start..<bytes.count], encoding: .utf8) else {
                throw EditAdapterServiceError.invalid("apply_unified_diff requires valid UTF-8 source text")
            }
            result.append(SourceLine(text: text, startByte: start, endByte: bytes.count))
        }
        return result
    }

    private func findHeader(_ diff: [String], context: ToolExecutionContext?) throws -> Int {
        for index in diff.indices {
            if (index & 0x3FF) == 0 {
                try requireContinue(context, message: "apply_unified_diff cancelled before header")
            }
            if diff[index].hasPrefix("--- ") { return index }
        }
        return -1
    }

    private func validateHeaderPath(_ raw: String, relativePath: String, side: String) throws {
        var token = raw.components(separatedBy: "\t").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty, token != "/dev/null" else {
            throw EditAdapterServiceError.invalid("apply_unified_diff \(side) path header is unsupported")
        }
        token = token.replacingOccurrences(of: "\\", with: "/")
        if token.hasPrefix("a/") || token.hasPrefix("b/") {
            token = String(token.dropFirst(2))
        }
        if token.hasPrefix("/") || isWindowsRooted(token) {
            throw EditAdapterServiceError.invalid("apply_unified_diff \(side) path header escapes the workspace")
        }
        let components = token.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) {
            throw EditAdapterServiceError.invalid("apply_unified_diff \(side) path header escapes the workspace")
        }

        var expected = relativePath.replacingOccurrences(of: "\\", with: "/")
        while expected.hasPrefix("./") { expected = String(expected.dropFirst(2)) }
        expected = expected.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard token == expected else {
            throw EditAdapterServiceError.invalid("apply_unified_diff \(side) path header does not match relative_path")
        }
    }

    private func isWindowsRooted(_ value: String) -> Bool {
        let chars = Array(value.utf8)
        guard chars.count >= 3 else { return false }
        let first = chars[0]
        let isLetter = (first >= 65 && first <= 90) || (first >= 97 && first <= 122)
        return isLetter && chars[1] == 58 && chars[2] == 47
    }

    private func parseHunkHeader(_ line: String) throws -> HunkHeader {
        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = Self.hunkRegex.firstMatch(in: line, options: [], range: range) else {
            throw EditAdapterServiceError.invalid("apply_unified_diff malformed hunk header: \(line)")
        }
        func value(_ group: Int, fallback: Int?) throws -> Int {
            let r = match.range(at: group)
            if r.location == NSNotFound {
                if let fallback { return fallback }
                throw EditAdapterServiceError.invalid("apply_unified_diff malformed hunk header")
            }
            guard let parsed = Int(ns.substring(with: r)), parsed >= 0 else {
                throw EditAdapterServiceError.invalid("apply_unified_diff malformed hunk header")
            }
            return parsed
        }
        return HunkHeader(
            oldStart: try value(1, fallback: nil),
            oldCount: try value(2, fallback: 1),
            newStart: try value(3, fallback: nil),
            newCount: try value(4, fallback: 1)
        )
    }

    private func validateHunkBounds(
        oldStart: Int,
        oldCount: Int,
        newStart: Int,
        newCount: Int,
        lineCount: Int
    ) throws {
        if oldCount == 0 {
            guard oldStart >= 0, oldStart <= lineCount else {
                throw EditAdapterServiceError.invalid("apply_unified_diff insertion hunk is outside source bounds")
            }
        } else {
            guard oldStart >= 1, oldStart - 1 <= lineCount - oldCount else {
                throw EditAdapterServiceError.invalid("apply_unified_diff hunk is outside source bounds")
            }
        }
        if newCount > 0, newStart < 1 {
            throw EditAdapterServiceError.invalid("apply_unified_diff new hunk start is invalid")
        }
    }

    private func hunkByteRange(
        lines: [SourceLine],
        oldStart: Int,
        oldCount: Int
    ) throws -> (Int, Int) {
        if oldCount == 0 {
            let position = oldStart == 0 ? 0 : lines[oldStart - 1].endByte
            return (position, position)
        }
        let first = oldStart - 1
        let last = first + oldCount - 1
        guard first >= 0, last < lines.count else {
            throw EditAdapterServiceError.invalid("apply_unified_diff hunk is outside source bounds")
        }
        return (lines[first].startByte, lines[last].endByte)
    }

    private func requireContinue(_ context: ToolExecutionContext?, message: String) throws {
        guard let context else { return }
        guard context.tryContinue() else {
            throw EditAdapterServiceError.invalid(message)
        }
    }

    private struct SourceLine {
        let text: String
        let startByte: Int
        let endByte: Int
    }

    private struct HunkHeader {
        let oldStart: Int
        let oldCount: Int
        let newStart: Int
        let newCount: Int
    }

    private struct CompiledHunk {
        let start: Int
        let end: Int
        let replacement: String
        let hunkIndex: Int
    }
}
