import Foundation

enum ToolExecutionContextError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case let .invalid(message): return message }
    }
}

struct ToolBudgetLimits {
    let maxVisitedEntries: Int
    let maxFilesScanned: Int
    let maxBytesScanned: Int64
    let maxOutputItems: Int
    let timeoutMs: Int

    static let serverCaps = ToolBudgetLimits(
        maxVisitedEntries: 50_000,
        maxFilesScanned: 50_000,
        maxBytesScanned: 50_000_000,
        maxOutputItems: 1_000,
        timeoutMs: 120_000
    )
}

final class ToolExecutionContext {
    static let budgetMetadataKey = "io.filemcp/budget"

    let limits: ToolBudgetLimits
    private let nowProvider: () -> Date
    private let cancellationProbe: () -> Bool
    private let deadline: Date

    private(set) var visitedEntries = 0
    private(set) var filesScanned = 0
    private(set) var bytesScanned: Int64 = 0
    private(set) var outputItems = 0
    private(set) var truncated = false
    private(set) var truncationReason = "none"
    var remainingFiles: Int { max(0, limits.maxFilesScanned - filesScanned) }
    var remainingBytes: Int64 { max(0, limits.maxBytesScanned - bytesScanned) }

    init(
        meta: [String: Any]?,
        nowProvider: @escaping () -> Date = Date.init,
        cancellationProbe: @escaping () -> Bool = { false }
    ) throws {
        var limits = ToolBudgetLimits.serverCaps
        if let rawBudget = meta?[Self.budgetMetadataKey] {
            guard let budget = rawBudget as? [String: Any] else {
                throw ToolExecutionContextError.invalid("\(Self.budgetMetadataKey) must be an object")
            }
            let allowed: Set<String> = [
                "maxVisitedEntries", "maxFilesScanned", "maxBytesScanned", "maxOutputItems", "timeoutMs",
            ]
            for key in budget.keys where !allowed.contains(key) {
                throw ToolExecutionContextError.invalid("Unknown budget field: \(key)")
            }
            limits = ToolBudgetLimits(
                maxVisitedEntries: try Self.lowerInt(budget, "maxVisitedEntries", limits.maxVisitedEntries),
                maxFilesScanned: try Self.lowerInt(budget, "maxFilesScanned", limits.maxFilesScanned),
                maxBytesScanned: try Self.lowerInt64(budget, "maxBytesScanned", limits.maxBytesScanned),
                maxOutputItems: try Self.lowerInt(budget, "maxOutputItems", limits.maxOutputItems),
                timeoutMs: try Self.lowerInt(budget, "timeoutMs", limits.timeoutMs)
            )
        }

        self.limits = limits
        self.nowProvider = nowProvider
        self.cancellationProbe = cancellationProbe
        self.deadline = nowProvider().addingTimeInterval(Double(limits.timeoutMs) / 1000.0)
    }

    static func hasBudget(_ meta: [String: Any]?) -> Bool {
        meta?[budgetMetadataKey] != nil
    }

    @discardableResult
    func tryContinue() -> Bool {
        if cancellationProbe() { return truncate("cancelled") }
        if nowProvider() >= deadline { return truncate("timeout") }
        return true
    }

    @discardableResult
    func tryVisitEntry() -> Bool {
        guard tryContinue() else { return false }
        guard visitedEntries < limits.maxVisitedEntries else { return truncate("visited_entries") }
        visitedEntries += 1
        return true
    }

    @discardableResult
    func tryScanFile(bytes: Int64) -> Bool {
        guard tryContinue() else { return false }
        guard filesScanned < limits.maxFilesScanned else { return truncate("files_scanned") }
        guard bytes >= 0, bytes <= limits.maxBytesScanned - bytesScanned else { return truncate("bytes_scanned") }
        filesScanned += 1
        bytesScanned += bytes
        return true
    }

    @discardableResult
    func tryOutputItem() -> Bool {
        guard tryContinue() else { return false }
        guard outputItems < limits.maxOutputItems else { return truncate("output_items") }
        outputItems += 1
        return true
    }

    func markTruncated(_ reason: String) {
        _ = truncate(reason)
    }

    func usage() -> [String: Any] {
        [
            "visitedEntries": visitedEntries,
            "filesScanned": filesScanned,
            "bytesScanned": bytesScanned,
            "outputItems": outputItems,
            "truncated": truncated,
            "truncationReason": truncationReason,
            "budget": [
                "maxVisitedEntries": limits.maxVisitedEntries,
                "maxFilesScanned": limits.maxFilesScanned,
                "maxBytesScanned": limits.maxBytesScanned,
                "maxOutputItems": limits.maxOutputItems,
                "timeoutMs": limits.timeoutMs,
            ],
        ]
    }

    @discardableResult
    private func truncate(_ reason: String) -> Bool {
        truncated = true
        if truncationReason == "none" {
            let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            truncationReason = trimmed.isEmpty ? "unknown" : trimmed
        }
        return false
    }

    private static func lowerInt(_ budget: [String: Any], _ key: String, _ serverCap: Int) throws -> Int {
        guard let raw = budget[key] else { return serverCap }
        guard !(raw is Bool), let number = raw as? NSNumber else {
            throw ToolExecutionContextError.invalid("Budget field \(key) must be a positive integer")
        }
        let value = number.intValue
        guard value > 0, number.doubleValue == Double(value) else {
            throw ToolExecutionContextError.invalid("Budget field \(key) must be a positive integer")
        }
        guard value <= serverCap else {
            throw ToolExecutionContextError.invalid("Budget field \(key) may only lower the server cap (\(serverCap))")
        }
        return value
    }

    private static func lowerInt64(_ budget: [String: Any], _ key: String, _ serverCap: Int64) throws -> Int64 {
        guard let raw = budget[key] else { return serverCap }
        guard !(raw is Bool), let number = raw as? NSNumber else {
            throw ToolExecutionContextError.invalid("Budget field \(key) must be a positive integer")
        }
        let value = number.int64Value
        guard value > 0, number.doubleValue == Double(value) else {
            throw ToolExecutionContextError.invalid("Budget field \(key) must be a positive integer")
        }
        guard value <= serverCap else {
            throw ToolExecutionContextError.invalid("Budget field \(key) may only lower the server cap (\(serverCap))")
        }
        return value
    }
}
