import AppKit
import Security

private let appName = "FileMCP"

private enum Layout {
    static let windowWidth: CGFloat = 620
    static let collapsedWindowHeight: CGFloat = 350
    static let expandedWindowHeight: CGFloat = 450
    static let footerHeight: CGFloat = 52
    static let contentWidth: CGFloat = 392
    static let labelWidth: CGFloat = 108
    static let fieldWidth: CGFloat = 276
    static let directoryFieldWidth: CGFloat = 224
    static let directoryButtonWidth: CGFloat = 44
    static let actionButtonHeight: CGFloat = 34
}

private enum ConfigKey {
    static let tunnelID = "tunnelID"
    static let profile = "profile"
    static let port = "port"
    static let allowedDirectory = "allowedDirectory"
    static let healthAddress = "healthAddress"
    static let gitUserName = "gitUserName"
    static let gitUserEmail = "gitUserEmail"
    static let apiKey = "apiKey"
    static let enableCommands = "enableCommands"
    static let policyProfile = "policyProfile"
    static let customPolicyMaxRisk = "customPolicyMaxRisk"
    static let customPolicyAllowedEffects = "customPolicyAllowedEffects"
    static let customPolicyAllowNetworkOpenWorld = "customPolicyAllowNetworkOpenWorld"
    static let customPolicyAllowShell = "customPolicyAllowShell"
    static let execEnvironmentAllowList = "execEnvironmentAllowList"
    static let executionBackendMode = "executionBackendMode"
    static let dockerImage = "dockerImage"
    static let dockerAllowedImages = "dockerAllowedImages"
    static let dockerNetworkEnabled = "dockerNetworkEnabled"
    static let dockerCpuLimit = "dockerCpuLimit"
    static let dockerMemoryMB = "dockerMemoryMB"
    static let dockerPidsLimit = "dockerPidsLimit"
    static let dockerUser = "dockerUser"
    static let dockerStartupTimeoutSeconds = "dockerStartupTimeoutSeconds"
    static let dockerIdleTTLSeconds = "dockerIdleTTLSeconds"
    static let dockerMaxLifetimeSeconds = "dockerMaxLifetimeSeconds"
}

private final class LoadingButton: NSButton {
    private let loadingGradientLayer = CAGradientLayer()
    private let loadingBorderMaskLayer = CAShapeLayer()
    private var borderPerimeter: CGFloat = 1

    convenience init(title: String, target: Any?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target as AnyObject?
        self.action = action
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLoadingBorder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLoadingBorder()
    }

    override func layout() {
        super.layout()
        let borderRect = bounds.insetBy(dx: 1, dy: 1)
        let cornerRadius: CGFloat = 8
        let perimeter = 2 * (borderRect.width + borderRect.height - 4 * cornerRadius)
            + 2 * .pi * cornerRadius
        borderPerimeter = max(perimeter, 1)

        loadingGradientLayer.frame = bounds
        loadingBorderMaskLayer.frame = bounds
        loadingBorderMaskLayer.path = CGPath(
            roundedRect: borderRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        loadingBorderMaskLayer.lineDashPattern = [
            NSNumber(value: Double(borderPerimeter * 0.2)),
            NSNumber(value: Double(borderPerimeter * 0.3)),
        ]
    }

    func setLoading(_ loading: Bool) {
        isEnabled = !loading
        loadingGradientLayer.isHidden = !loading

        if loading {
            loadingBorderMaskLayer.lineDashPhase = 0
            let animation = CABasicAnimation(keyPath: "lineDashPhase")
            animation.fromValue = 0
            animation.toValue = -borderPerimeter
            animation.duration = 1.5
            animation.repeatCount = .infinity
            loadingBorderMaskLayer.add(animation, forKey: "loading-border")
        } else {
            loadingBorderMaskLayer.removeAnimation(forKey: "loading-border")
            loadingBorderMaskLayer.lineDashPhase = 0
        }
    }

    private func configureLoadingBorder() {
        wantsLayer = true
        loadingGradientLayer.colors = [
            NSColor.controlAccentColor.cgColor,
            NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor,
        ]
        loadingGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        loadingGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        loadingGradientLayer.isHidden = true

        loadingBorderMaskLayer.fillColor = NSColor.clear.cgColor
        loadingBorderMaskLayer.strokeColor = NSColor.white.cgColor
        loadingBorderMaskLayer.lineWidth = 1
        loadingBorderMaskLayer.lineCap = .round
        loadingGradientLayer.mask = loadingBorderMaskLayer
        layer?.addSublayer(loadingGradientLayer)
    }
}

private final class RuntimeStorage {
    private let keychainService = Bundle.main.bundleIdentifier ?? "com.localfilesmcp.app"
    private let keychainAccount = "runtime-api-key"

    var hasSavedAPIKey: Bool {
        if let value = try? readKeychainAPIKey(), !value.isEmpty { return true }
        return legacyAPIKey != nil
    }

    func readAPIKey() throws -> String {
        if let value = try readKeychainAPIKey(), !value.isEmpty { return value }
        if let legacy = legacyAPIKey {
            try saveAPIKey(legacy)
            return legacy
        }
        throw NSError(domain: appName, code: 1, userInfo: [NSLocalizedDescriptionKey: "No API key is saved."])
    }

    func saveAPIKey(_ value: String) throws {
        guard !value.isEmpty else { return }
        guard let data = value.data(using: .utf8) else {
            throw NSError(domain: appName, code: 2, userInfo: [NSLocalizedDescriptionKey: "The API key is not valid UTF-8."])
        }
        let query = keychainQuery()
        let attributes: [CFString: Any] = [kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            item[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw keychainError(operation: "save the API key", status: addStatus) }
        } else if updateStatus != errSecSuccess {
            throw keychainError(operation: "update the API key", status: updateStatus)
        }
        UserDefaults.standard.removeObject(forKey: ConfigKey.apiKey)
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(keychainQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw keychainError(operation: "delete the API key", status: status) }
        UserDefaults.standard.removeObject(forKey: ConfigKey.apiKey)
    }

    private var legacyAPIKey: String? {
        guard let value = UserDefaults.standard.string(forKey: ConfigKey.apiKey), !value.isEmpty else { return nil }
        return value
    }

    private func readKeychainAPIKey() throws -> String? {
        var query = keychainQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw keychainError(operation: "read the API key", status: status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw NSError(domain: appName, code: 3, userInfo: [NSLocalizedDescriptionKey: "The API key stored in Keychain is not valid UTF-8."])
        }
        return value
    }

    private func keychainQuery() -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: keychainService, kSecAttrAccount: keychainAccount]
    }

    private func keychainError(operation: String, status: OSStatus) -> NSError {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        return NSError(domain: appName, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not \(operation) in macOS Keychain: \(detail)"])
    }
}

private struct ActivityEvent {
    let timestamp: Date
    let kind: String
    let workspace: String
    let summary: String
    let detail: String
}

private struct ChangeEvent {
    let timestamp: Date
    let status: String
    let workspace: String
    let operation: String
    let summary: String
    let detail: String
}

private struct RepositoryItemEvent {
    let path: String
    let name: String
    let kind: String
    let detail: String
    let score: String
}

private struct RepositoryResultEvent {
    let timestamp: Date
    let workspace: String
    let queryKind: String
    let providerID: String
    let providerVersion: String
    let completeness: String
    let sourceStateID: String
    let grantsAuthority: Bool
    let rawSourcePersisted: Bool
    let partial: Bool
    let truncated: Bool
    let truncationReason: String?
    let returnedCount: Int
    let totalCount: Int
    let symbolSupport: Bool
    let ambiguous: Bool
    let displayTruncated: Bool
    let artifactState: String
    let entries: [RepositoryItemEvent]
}

private struct TerminalSessionEvent {
    let sessionID: String
    let pid: Int?
    let state: String
    let lastActivityEpochMs: Int64
    let earliestCursor: String
    let endCursor: String
    let exitCode: Int?
    let spillRefCount: Int
    let actualPTY: Bool
    let restartResumeSupported: Bool
    let grantsAuthority: Bool
    let backendID: String
    let backendVersion: String
    let backendCapabilities: String
    let policyProfile: String
    let policyGeneration: Int64
    let policyHash: String

    var isControllable: Bool { state.caseInsensitiveCompare("running") == .orderedSame }
}

private struct ArtifactBatchEntryEvent {
    let path: String
    let state: String
    let delivery: String
    let sizeBytes: Int64?
    let maxBytes: Int64?
    let versionStrength: String?
    let expiresEpochMs: Int64?
    let blobID: String?
    let contentRefPresent: Bool
    let errorCode: String?
    let message: String?
}

private struct ArtifactBatchEvent {
    let timestamp: Date
    let workspace: String
    let operation: String
    let requestedCount: Int
    let completedCount: Int
    let partial: Bool
    let cancelled: Bool
    let truncated: Bool
    let truncationReason: String?
    let contentRefCount: Int
    let quotaErrorCount: Int
    let entries: [ArtifactBatchEntryEvent]
}

private struct EvidenceEvent {
    let timestamp: Date
    let workspace: String
    let evidenceID: String
    let operationID: String
    let criterion: String
    let verificationState: String
    let operationState: String
    let storageStatus: String
    let sourceBinding: String
    let sourceStateID: String?
    let projectContextDigest: String?
    let policyHash: String
    let catalogHash: String
    let catalogVersion: String
    let blockReason: String?
}

private final class MainViewController: NSViewController, NSTabViewDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let storage = RuntimeStorage()
    private let runtime = LocalMCPRuntime()
    private var logBuffer = ""
    private var logFlushScheduled = false
    private let maxLogCharacters = 500_000
    private var activityEvents: [ActivityEvent] = []
    private var filteredActivityEvents: [ActivityEvent] = []
    private var changeEvents: [ChangeEvent] = []
    private var evidenceEvents: [EvidenceEvent] = []
    private var repositoryEvents: [RepositoryResultEvent] = []
    private var selectedRepositoryEvent: RepositoryResultEvent?
    private var terminalSessions: [TerminalSessionEvent] = []
    private var terminalReadCursors: [String: String] = [:]
    private var terminalRefreshInProgress = false
    private var terminalTimer: Timer?
    private let terminalReadWindowBytes = 16 * 1024
    private let maxTerminalOutputCharacters = 64 * 1024
    private var artifactBatchEvents: [ArtifactBatchEvent] = []
    private var selectedArtifactBatch: ArtifactBatchEvent?
    private let maxActivityEvents = 500
    private let maxChangeEvents = 250
    private let maxEvidenceEvents = 500
    private let maxRepositoryEvents = 100
    private let maxArtifactBatchEvents = 100

    private let tunnelIDField = NSTextField()
    private let apiKeyField = NSSecureTextField()
    private let profileField = NSTextField()
    private let portField = NSTextField()
    private let directoryField = NSTextField()
    private let healthAddressField = NSTextField()
    private let gitUserNameField = NSTextField()
    private let gitUserEmailField = NSTextField()
    private let execEnvironmentAllowListField = NSTextField()
    private let enableCommandsCheckbox = NSButton(checkboxWithTitle: "Allow shell commands", target: nil, action: nil)
    private let policyProfilePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let policyExplanationLabel = NSTextField(wrappingLabelWithString: "Policy is owned by local settings.")
    private let logView = NSTextView()
    private let activityTableView = NSTableView()
    private let activityDetailLabel = NSTextField(wrappingLabelWithString: "Select an activity event.")
    private let activityFilterPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let changesTableView = NSTableView()
    private let changesDetailLabel = NSTextField(wrappingLabelWithString: "Select a captured mutation event.")
    private let evidenceTableView = NSTableView()
    private let evidenceDetailLabel = NSTextField(wrappingLabelWithString: "Select an evidence record.")
    private let repositoryResultTableView = NSTableView()
    private let repositoryItemTableView = NSTableView()
    private let repositoryProviderLabel = NSTextField(wrappingLabelWithString: "No repository-intelligence result captured yet.")
    private let repositorySummaryLabel = NSTextField(wrappingLabelWithString: "Waiting for real repo_map, symbol_search or related_files output.")
    private let repositorySourceLabel = NSTextField(wrappingLabelWithString: "Source state: not observed")
    private let repositoryItemDetailLabel = NSTextField(wrappingLabelWithString: "Select an observed repository result.")
    private let terminalTableView = NSTableView()
    private let terminalOutputView = NSTextView()
    private let terminalBackendLabel = NSTextField(wrappingLabelWithString: "No live PTY session observed.")
    private let terminalPolicyLabel = NSTextField(wrappingLabelWithString: "No connected workspace selected.")
    private let terminalStatusLabel = NSTextField(wrappingLabelWithString: "0 observed PTY sessions | restart resume unsupported")
    private let terminalCtrlCButton = NSButton(title: "Ctrl+C", target: nil, action: nil)
    private let terminalStopButton = NSButton(title: "Stop", target: nil, action: nil)
    private let terminalResizeButton = NSButton(title: "Resize", target: nil, action: nil)
    private let terminalColumnsField = NSTextField(string: "120")
    private let terminalRowsField = NSTextField(string: "30")
    private let artifactBatchTableView = NSTableView()
    private let artifactEntryTableView = NSTableView()
    private let artifactBatchSummaryLabel = NSTextField(wrappingLabelWithString: "No batch result captured yet.")
    private let artifactQuotaSummaryLabel = NSTextField(wrappingLabelWithString: "Quota usage remaining is not emitted by batch results.")
    private let artifactEntryDetailLabel = NSTextField(wrappingLabelWithString: "Select a captured batch entry.")
    private let saveConnectionButton = LoadingButton(title: "Save connection", target: nil, action: nil)
    private let saveSettingsButton = LoadingButton(title: "Save settings", target: nil, action: nil)
    private let startButton = NSButton(title: "Connect", target: nil, action: nil)
    private let deleteKeyButton = NSButton(title: "Delete API key", target: nil, action: nil)
    private let quitButton = NSButton(title: "Quit FileMCP", target: nil, action: nil)
    private let advancedToggleButton = NSButton(title: "Advanced options", target: nil, action: nil)
    private let advancedSettingsGroup = NSStackView()
    private let apiKeyStatusLabel = NSTextField(labelWithString: "")
    private let connectionStatusLabel = NSTextField(labelWithString: "Runtime stopped")
    private let connectionDiagnosticsLabel = NSTextField(wrappingLabelWithString: "No runtime is connected.")
    private let shellStatusLabel = NSTextField(labelWithString: "Runtime stopped")
    private let homeStatusLabel = NSTextField(labelWithString: "Runtime stopped")
    private let homeWorkspaceLabel = NSTextField(labelWithString: "No workspace selected")
    private let homeRecentEventLabel = NSTextField(labelWithString: "No recent issue")
    private let workspaceRootLabel = NSTextField(labelWithString: "Not configured")
    private let workspaceStatusLabel = NSTextField(labelWithString: "Stopped")
    private let workspacePolicyLabel = NSTextField(labelWithString: "Default")
    private let workspaceConnectionLabel = NSTextField(labelWithString: "Disconnected")
    private var lastImportantEvent = "No recent issue"
    private let tabs = NSTabView()

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        loadConfiguration()
        configureRuntime()
    }

    deinit { shutdownForTermination() }

    private func buildUI() {
        configure(tunnelIDField, placeholder: "tunnel_...")
        configure(apiKeyField, placeholder: "sk-...")
        configure(profileField, placeholder: "filemcp")
        profileField.toolTip = "Starts with a letter or number; use only letters, numbers, '.', '_' or '-' (maximum 128 characters)."
        configure(portField, placeholder: "8008")
        configure(directoryField, placeholder: "Choose a shared directory")
        configure(healthAddressField, placeholder: "127.0.0.1:0")
        healthAddressField.toolTip = "Loopback-only tunnel-client health/admin listener. Use port 0 for an ephemeral port."
        configure(gitUserNameField, placeholder: "Git name for commits (optional)")
        configure(gitUserEmailField, placeholder: "Git email for commits (optional)")
        configure(execEnvironmentAllowListField, placeholder: "VAR_NAME, PREFIX_*")
        execEnvironmentAllowListField.toolTip = "Comma-separated environment names/glob patterns allowed for exec_process. Secret-like names require an exact entry."

        let chooseImage = NSImage(systemSymbolName: "folder", accessibilityDescription: "Choose directory")!
        let chooseButton = NSButton(image: chooseImage, target: self, action: #selector(chooseDirectory))
        chooseButton.bezelStyle = .rounded
        chooseButton.imagePosition = .imageOnly
        chooseButton.toolTip = "Choose directory"

        logView.isEditable = false
        logView.isSelectable = true
        logView.isVerticallyResizable = true
        logView.isHorizontallyResizable = true
        logView.autoresizingMask = [.width, .height]
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0)
        logView.textColor = NSColor.white
        logView.insertionPointColor = NSColor.white
        logView.string = ""
        let logScroll = NSScrollView()
        logScroll.hasVerticalScroller = true
        logScroll.hasHorizontalScroller = true
        logScroll.autohidesScrollers = true
        logScroll.borderType = .bezelBorder
        logView.frame = logScroll.contentView.bounds
        logView.minSize = NSSize(width: 0, height: logScroll.contentSize.height)
        logView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        logView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        logView.textContainer?.widthTracksTextView = false
        logScroll.documentView = logView

        activityTableView.delegate = self
        activityTableView.dataSource = self
        activityTableView.headerView = NSTableHeaderView()
        activityTableView.usesAlternatingRowBackgroundColors = true
        activityTableView.allowsMultipleSelection = false

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("activity-time"))
        timeColumn.title = "Time"
        timeColumn.width = 72
        activityTableView.addTableColumn(timeColumn)

        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("activity-type"))
        typeColumn.title = "Type"
        typeColumn.width = 90
        activityTableView.addTableColumn(typeColumn)

        let workspaceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("activity-workspace"))
        workspaceColumn.title = "Workspace"
        workspaceColumn.width = 84
        activityTableView.addTableColumn(workspaceColumn)

        let summaryColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("activity-summary"))
        summaryColumn.title = "Summary"
        summaryColumn.width = 260
        activityTableView.addTableColumn(summaryColumn)

        activityFilterPopup.addItems(withTitles: ["All activity", "Errors only", "Workspace/runtime", "Settings/connection"])
        activityFilterPopup.target = self
        activityFilterPopup.action = #selector(activityFilterChanged)

        changesTableView.delegate = self
        changesTableView.dataSource = self
        changesTableView.headerView = NSTableHeaderView()
        changesTableView.usesAlternatingRowBackgroundColors = true
        changesTableView.allowsMultipleSelection = false
        for (identifier, title, width) in [
            ("change-time", "Time", 72.0),
            ("change-status", "Status", 82.0),
            ("change-workspace", "Workspace", 84.0),
            ("change-operation", "Operation", 104.0),
            ("change-summary", "Summary", 250.0),
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            changesTableView.addTableColumn(column)
        }

        evidenceTableView.delegate = self
        evidenceTableView.dataSource = self
        evidenceTableView.headerView = NSTableHeaderView()
        evidenceTableView.usesAlternatingRowBackgroundColors = true
        evidenceTableView.allowsMultipleSelection = false
        for (identifier, title, width) in [
            ("evidence-time", "Time", 72.0),
            ("evidence-state", "State", 90.0),
            ("evidence-workspace", "Workspace", 84.0),
            ("evidence-criterion", "Criterion", 120.0),
            ("evidence-id", "Evidence ID", 260.0),
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            evidenceTableView.addTableColumn(column)
        }

        repositoryResultTableView.delegate = self
        repositoryResultTableView.dataSource = self
        repositoryResultTableView.headerView = NSTableHeaderView()
        repositoryResultTableView.usesAlternatingRowBackgroundColors = true
        repositoryResultTableView.allowsMultipleSelection = false
        for (identifier, title, width) in [
            ("repository-time", "Time", 72.0),
            ("repository-workspace", "Workspace", 84.0),
            ("repository-query", "Query", 110.0),
            ("repository-count", "Returned", 88.0),
            ("repository-state", "State", 90.0),
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            repositoryResultTableView.addTableColumn(column)
        }

        repositoryItemTableView.delegate = self
        repositoryItemTableView.dataSource = self
        repositoryItemTableView.headerView = NSTableHeaderView()
        repositoryItemTableView.usesAlternatingRowBackgroundColors = true
        repositoryItemTableView.allowsMultipleSelection = false
        for (identifier, title, width) in [
            ("repository-item-path", "Path", 210.0),
            ("repository-item-name", "Name / language", 120.0),
            ("repository-item-kind", "Kind", 90.0),
            ("repository-item-detail", "Detail", 230.0),
            ("repository-item-score", "Score", 64.0),
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            repositoryItemTableView.addTableColumn(column)
        }
        repositoryProviderLabel.maximumNumberOfLines = 4
        repositorySummaryLabel.maximumNumberOfLines = 4
        repositorySummaryLabel.textColor = .secondaryLabelColor
        repositorySourceLabel.maximumNumberOfLines = 3
        repositorySourceLabel.textColor = .secondaryLabelColor
        repositoryItemDetailLabel.maximumNumberOfLines = 5
        repositoryItemDetailLabel.textColor = .secondaryLabelColor

        terminalTableView.delegate = self
        terminalTableView.dataSource = self
        terminalTableView.headerView = NSTableHeaderView()
        terminalTableView.usesAlternatingRowBackgroundColors = true
        terminalTableView.allowsMultipleSelection = false
        for (identifier, title, width) in [
            ("terminal-state", "State", 86.0),
            ("terminal-pid", "PID", 72.0),
            ("terminal-session", "Session", 260.0),
            ("terminal-activity", "Last activity", 110.0),
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            terminalTableView.addTableColumn(column)
        }

        terminalOutputView.isEditable = false
        terminalOutputView.isSelectable = true
        terminalOutputView.isRichText = false
        terminalOutputView.isHorizontallyResizable = true
        terminalOutputView.autoresizingMask = [.width, .height]
        terminalOutputView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        terminalOutputView.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0)
        terminalOutputView.textColor = .white
        terminalOutputView.insertionPointColor = .white
        terminalOutputView.string = ""
        terminalBackendLabel.maximumNumberOfLines = 4
        terminalPolicyLabel.maximumNumberOfLines = 4
        terminalStatusLabel.maximumNumberOfLines = 3
        terminalStatusLabel.textColor = .secondaryLabelColor

        terminalCtrlCButton.target = self
        terminalCtrlCButton.action = #selector(terminalSendCtrlC)
        terminalStopButton.target = self
        terminalStopButton.action = #selector(terminalStopSession)
        terminalResizeButton.target = self
        terminalResizeButton.action = #selector(terminalResizeSession)
        terminalCtrlCButton.isEnabled = false
        terminalStopButton.isEnabled = false
        terminalResizeButton.isEnabled = false
        terminalColumnsField.alignment = .right
        terminalRowsField.alignment = .right

        artifactBatchTableView.delegate = self
        artifactBatchTableView.dataSource = self
        artifactBatchTableView.headerView = NSTableHeaderView()
        artifactBatchTableView.usesAlternatingRowBackgroundColors = true
        artifactBatchTableView.allowsMultipleSelection = false
        for (identifier, title, width) in [
            ("artifact-time", "Time", 72.0),
            ("artifact-workspace", "Workspace", 84.0),
            ("artifact-operation", "Operation", 100.0),
            ("artifact-completed", "Completed", 88.0),
            ("artifact-state", "State", 92.0),
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            artifactBatchTableView.addTableColumn(column)
        }

        artifactEntryTableView.delegate = self
        artifactEntryTableView.dataSource = self
        artifactEntryTableView.headerView = NSTableHeaderView()
        artifactEntryTableView.usesAlternatingRowBackgroundColors = true
        artifactEntryTableView.allowsMultipleSelection = false
        for (identifier, title, width) in [
            ("artifact-entry-path", "Path", 220.0),
            ("artifact-entry-state", "State", 78.0),
            ("artifact-entry-delivery", "Delivery", 92.0),
            ("artifact-entry-size", "Size", 80.0),
            ("artifact-entry-expiry", "Expires", 118.0),
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            artifactEntryTableView.addTableColumn(column)
        }

        artifactBatchSummaryLabel.maximumNumberOfLines = 3
        artifactQuotaSummaryLabel.maximumNumberOfLines = 3
        artifactQuotaSummaryLabel.textColor = .secondaryLabelColor
        artifactEntryDetailLabel.maximumNumberOfLines = 12

        startButton.target = self
        startButton.action = #selector(startTunnel)
        startButton.keyEquivalent = "\r"
        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        updateRunButton(state: .stopped)

        saveConnectionButton.target = self
        saveConnectionButton.action = #selector(saveConnectionOnly)
        saveConnectionButton.bezelStyle = .rounded
        saveConnectionButton.controlSize = .large

        saveSettingsButton.target = self
        saveSettingsButton.action = #selector(saveSettingsOnly)
        saveSettingsButton.bezelStyle = .rounded

        deleteKeyButton.target = self
        deleteKeyButton.action = #selector(deleteSavedKey)
        deleteKeyButton.bezelStyle = .rounded
        deleteKeyButton.controlSize = .small
        deleteKeyButton.contentTintColor = .systemRed

        quitButton.target = self
        quitButton.action = #selector(quitApp)
        quitButton.bezelStyle = .rounded
        quitButton.controlSize = .small
        quitButton.contentTintColor = .systemRed

        advancedToggleButton.target = self
        advancedToggleButton.action = #selector(toggleAdvancedSettings)
        advancedToggleButton.bezelStyle = .inline
        advancedToggleButton.isBordered = false
        advancedToggleButton.image = advancedChevron(expanded: false)
        advancedToggleButton.imagePosition = .imageLeading
        advancedToggleButton.contentTintColor = .secondaryLabelColor

        apiKeyStatusLabel.font = .systemFont(ofSize: 10.5)
        apiKeyStatusLabel.textColor = .secondaryLabelColor
        apiKeyStatusLabel.lineBreakMode = .byTruncatingTail
        apiKeyStatusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        apiKeyStatusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        func fieldRow(_ label: String, _ field: NSView) -> NSStackView {
            let labelView = NSTextField(labelWithString: label)
            labelView.font = .systemFont(ofSize: 11, weight: .medium)
            labelView.alignment = .left
            labelView.cell?.alignment = .left
            labelView.textColor = .secondaryLabelColor
            labelView.setContentHuggingPriority(.required, for: .horizontal)
            labelView.setContentCompressionResistancePriority(.required, for: .horizontal)
            labelView.translatesAutoresizingMaskIntoConstraints = false
            labelView.widthAnchor.constraint(equalToConstant: Layout.labelWidth).isActive = true

            let row = NSStackView(views: [labelView, field])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            return row
        }

        func connectionField(_ label: String, _ field: NSView) -> NSStackView {
            let labelView = NSTextField(labelWithString: label)
            labelView.font = .systemFont(ofSize: 11, weight: .medium)
            labelView.alignment = .left
            labelView.cell?.alignment = .left
            labelView.textColor = .secondaryLabelColor
            labelView.setContentHuggingPriority(.required, for: .vertical)
            labelView.setContentCompressionResistancePriority(.required, for: .vertical)

            let row = NSStackView(views: [labelView, field])
            row.orientation = .vertical
            row.alignment = .leading
            row.spacing = 5
            return row
        }

        let connectionForm = NSStackView(views: [
            connectionField("Tunnel ID", tunnelIDField),
            connectionField("Runtime API key", apiKeyField),
        ])
        connectionForm.orientation = .vertical
        connectionForm.alignment = .leading
        connectionForm.spacing = 12

        let primaryActions = NSStackView(views: [saveConnectionButton, startButton])
        primaryActions.orientation = .horizontal
        primaryActions.alignment = .centerY
        primaryActions.distribution = .fillEqually
        primaryActions.spacing = 8
        primaryActions.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        let keyManagementRow = NSStackView(views: [apiKeyStatusLabel, deleteKeyButton])
        keyManagementRow.orientation = .horizontal
        keyManagementRow.alignment = .centerY
        keyManagementRow.spacing = 10
        keyManagementRow.translatesAutoresizingMaskIntoConstraints = false

        let connectionSpacer = NSView()
        connectionSpacer.translatesAutoresizingMaskIntoConstraints = false
        connectionSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        connectionSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        connectionStatusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        connectionDiagnosticsLabel.textColor = .secondaryLabelColor
        connectionDiagnosticsLabel.maximumNumberOfLines = 3

        let connectionHeader = FileMCPFeedbackComponents.pageHeader(
            title: "Connections",
            description: "Runtime credentials, Secure MCP Tunnel configuration and connectivity health."
        )

        let connectionSummary = NSStackView(views: [
            connectionStatusLabel,
            connectionDiagnosticsLabel,
        ])
        connectionSummary.orientation = .vertical
        connectionSummary.alignment = .leading
        connectionSummary.spacing = 4

        let connectionRoot = NSStackView(views: [
            connectionHeader,
            connectionSummary,
            connectionForm,
            primaryActions,
            divider,
            keyManagementRow,
            connectionSpacer,
        ])
        connectionRoot.orientation = .vertical
        connectionRoot.alignment = .leading
        connectionRoot.spacing = 12
        connectionRoot.setCustomSpacing(16, after: connectionForm)
        connectionRoot.setCustomSpacing(14, after: primaryActions)
        connectionRoot.setCustomSpacing(10, after: divider)
        connectionRoot.translatesAutoresizingMaskIntoConstraints = false

        let connectionPage = NSView()
        connectionPage.addSubview(connectionRoot)
        NSLayoutConstraint.activate([
            connectionRoot.leadingAnchor.constraint(equalTo: connectionPage.leadingAnchor, constant: 12),
            connectionRoot.trailingAnchor.constraint(equalTo: connectionPage.trailingAnchor, constant: -12),
            connectionRoot.topAnchor.constraint(equalTo: connectionPage.topAnchor, constant: 12),
            connectionRoot.bottomAnchor.constraint(equalTo: connectionPage.bottomAnchor, constant: -12),
            primaryActions.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            divider.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            keyManagementRow.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            saveConnectionButton.heightAnchor.constraint(equalToConstant: Layout.actionButtonHeight),
            startButton.heightAnchor.constraint(equalToConstant: Layout.actionButtonHeight),
        ])

        let directoryControls = NSStackView(views: [directoryField, chooseButton])
        directoryControls.orientation = .horizontal
        directoryControls.alignment = .centerY
        directoryControls.spacing = 8
        directoryField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        directoryField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        enableCommandsCheckbox.isHidden = true
        policyProfilePopup.removeAllItems()
        let policyOptions: [(String, String, Bool)] = [
            ("Restricted (legacy-safe compatibility)", FileMCPPolicyProfiles.restricted, true),
            ("Workspace auto", FileMCPPolicyProfiles.workspaceAuto, true),
            ("Custom (advanced local policy)", FileMCPPolicyProfiles.custom, true),
            ("Legacy command compatible (migrated only)", FileMCPPolicyProfiles.legacyCommandCompatible, false),
        ]
        policyProfilePopup.target = self
        policyProfilePopup.action = #selector(policyProfileChanged)
        for (title, value, enabled) in policyOptions {
            policyProfilePopup.addItem(withTitle: title)
            if let item = policyProfilePopup.lastItem {
                item.representedObject = value
                item.isEnabled = enabled
            }
        }
        policyExplanationLabel.font = .systemFont(ofSize: 10)
        policyExplanationLabel.textColor = .secondaryLabelColor
        policyExplanationLabel.maximumNumberOfLines = 0
        policyExplanationLabel.preferredMaxLayoutWidth = Layout.contentWidth

        let policyRow = fieldRow("Policy", policyProfilePopup)
        let profileRow = fieldRow("Profile", profileField)
        let portRow = fieldRow("MCP port", portField)
        let directoryRow = fieldRow("Shared directory", directoryControls)
        let healthRow = fieldRow("Health listener", healthAddressField)
        let gitNameRow = fieldRow("Git name", gitUserNameField)
        let gitEmailRow = fieldRow("Git email", gitUserEmailField)
        let execEnvironmentRow = fieldRow("Exec env allowlist", execEnvironmentAllowListField)

        advancedSettingsGroup.orientation = .vertical
        advancedSettingsGroup.alignment = .leading
        advancedSettingsGroup.spacing = 8
        advancedSettingsGroup.detachesHiddenViews = true
        [profileRow, portRow, healthRow, gitNameRow, gitEmailRow, execEnvironmentRow].forEach {
            advancedSettingsGroup.addArrangedSubview($0)
        }
        advancedSettingsGroup.isHidden = true
        advancedSettingsGroup.translatesAutoresizingMaskIntoConstraints = false

        let workspaceSection = NSTextField(labelWithString: "Workspace & access")
        workspaceSection.font = .systemFont(ofSize: 13, weight: .semibold)
        let policySection = NSTextField(labelWithString: "Policy")
        policySection.font = .systemFont(ofSize: 13, weight: .semibold)
        let appearanceSection = NSTextField(labelWithString: "Appearance")
        appearanceSection.font = .systemFont(ofSize: 13, weight: .semibold)
        let appearanceExplanation = NSTextField(wrappingLabelWithString: "Follows macOS system appearance and accessibility contrast settings. Manual theme override is not exposed.")
        appearanceExplanation.font = .systemFont(ofSize: 10)
        appearanceExplanation.textColor = .secondaryLabelColor

        let settingsHeader = FileMCPFeedbackComponents.pageHeader(
            title: "Settings",
            description: "Workspace access, policy, execution, Git, telemetry and appearance."
        )
        let settingsForm = NSStackView(views: [
            settingsHeader,
            workspaceSection,
            directoryRow,
            policySection,
            policyRow,
            policyExplanationLabel,
            advancedToggleButton,
            advancedSettingsGroup,
            appearanceSection,
            appearanceExplanation,
        ])
        settingsForm.orientation = .vertical
        settingsForm.alignment = .leading
        settingsForm.spacing = 8
        settingsForm.setCustomSpacing(14, after: policyExplanationLabel)
        settingsForm.setCustomSpacing(10, after: advancedToggleButton)
        settingsForm.translatesAutoresizingMaskIntoConstraints = false

        let settingsRoot = NSStackView(views: [settingsForm, saveSettingsButton])
        settingsRoot.orientation = .vertical
        settingsRoot.alignment = .leading
        settingsRoot.spacing = 10
        settingsRoot.translatesAutoresizingMaskIntoConstraints = false

        let settingsPage = NSView()
        settingsPage.addSubview(settingsRoot)
        NSLayoutConstraint.activate([
            settingsRoot.leadingAnchor.constraint(equalTo: settingsPage.leadingAnchor, constant: 12),
            settingsRoot.trailingAnchor.constraint(equalTo: settingsPage.trailingAnchor, constant: -12),
            settingsRoot.topAnchor.constraint(equalTo: settingsPage.topAnchor, constant: 12),
            settingsRoot.bottomAnchor.constraint(lessThanOrEqualTo: settingsPage.bottomAnchor, constant: -10),
        ])

        logScroll.translatesAutoresizingMaskIntoConstraints = false
        logScroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        logScroll.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        let activityScroll = NSScrollView()
        activityScroll.documentView = activityTableView
        activityScroll.hasVerticalScroller = true
        activityScroll.borderType = .bezelBorder
        activityScroll.translatesAutoresizingMaskIntoConstraints = false

        let activityHeader = FileMCPFeedbackComponents.pageHeader(
            title: "Activity",
            description: "Structured runtime, workspace and error events. Raw logs remain under Diagnostics."
        )
        let activityRoot = NSStackView(views: [activityHeader, activityFilterPopup, activityScroll, activityDetailLabel])
        activityRoot.orientation = .vertical
        activityRoot.alignment = .leading
        activityRoot.spacing = 8
        activityRoot.translatesAutoresizingMaskIntoConstraints = false
        activityDetailLabel.maximumNumberOfLines = 6

        let activityPage = NSView()
        activityPage.addSubview(activityRoot)
        NSLayoutConstraint.activate([
            activityRoot.leadingAnchor.constraint(equalTo: activityPage.leadingAnchor, constant: 12),
            activityRoot.trailingAnchor.constraint(equalTo: activityPage.trailingAnchor, constant: -12),
            activityRoot.topAnchor.constraint(equalTo: activityPage.topAnchor, constant: 12),
            activityRoot.bottomAnchor.constraint(equalTo: activityPage.bottomAnchor, constant: -12),
            activityScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])

        let changesScroll = NSScrollView()
        changesScroll.documentView = changesTableView
        changesScroll.hasVerticalScroller = true
        changesScroll.borderType = .bezelBorder
        changesScroll.translatesAutoresizingMaskIntoConstraints = false

        let changesHeader = FileMCPFeedbackComponents.pageHeader(
            title: "Changes",
            description: "Observed mutation results and stale/conflict states. No synthetic diff is generated."
        )
        changesDetailLabel.maximumNumberOfLines = 10
        let changesRoot = NSStackView(views: [changesHeader, changesScroll, changesDetailLabel])
        changesRoot.orientation = .vertical
        changesRoot.alignment = .leading
        changesRoot.spacing = 8
        changesRoot.translatesAutoresizingMaskIntoConstraints = false

        let changesPage = NSView()
        changesPage.addSubview(changesRoot)
        NSLayoutConstraint.activate([
            changesRoot.leadingAnchor.constraint(equalTo: changesPage.leadingAnchor, constant: 12),
            changesRoot.trailingAnchor.constraint(equalTo: changesPage.trailingAnchor, constant: -12),
            changesRoot.topAnchor.constraint(equalTo: changesPage.topAnchor, constant: 12),
            changesRoot.bottomAnchor.constraint(equalTo: changesPage.bottomAnchor, constant: -12),
            changesScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])

        let evidenceScroll = NSScrollView()
        evidenceScroll.documentView = evidenceTableView
        evidenceScroll.hasVerticalScroller = true
        evidenceScroll.borderType = .bezelBorder
        evidenceScroll.translatesAutoresizingMaskIntoConstraints = false

        let evidenceHeader = FileMCPFeedbackComponents.pageHeader(
            title: "Evidence",
            description: "Server-owned verification records with source, policy and catalog linkage."
        )
        evidenceDetailLabel.maximumNumberOfLines = 14
        let evidenceRoot = NSStackView(views: [evidenceHeader, evidenceScroll, evidenceDetailLabel])
        evidenceRoot.orientation = .vertical
        evidenceRoot.alignment = .leading
        evidenceRoot.spacing = 8
        evidenceRoot.translatesAutoresizingMaskIntoConstraints = false

        let evidencePage = NSView()
        evidencePage.addSubview(evidenceRoot)
        NSLayoutConstraint.activate([
            evidenceRoot.leadingAnchor.constraint(equalTo: evidencePage.leadingAnchor, constant: 12),
            evidenceRoot.trailingAnchor.constraint(equalTo: evidencePage.trailingAnchor, constant: -12),
            evidenceRoot.topAnchor.constraint(equalTo: evidencePage.topAnchor, constant: 12),
            evidenceRoot.bottomAnchor.constraint(equalTo: evidencePage.bottomAnchor, constant: -12),
            evidenceScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])

        let repositoryResultScroll = NSScrollView()
        repositoryResultScroll.documentView = repositoryResultTableView
        repositoryResultScroll.hasVerticalScroller = true
        repositoryResultScroll.borderType = .bezelBorder
        repositoryResultScroll.translatesAutoresizingMaskIntoConstraints = false

        let repositoryItemScroll = NSScrollView()
        repositoryItemScroll.documentView = repositoryItemTableView
        repositoryItemScroll.hasVerticalScroller = true
        repositoryItemScroll.borderType = .bezelBorder
        repositoryItemScroll.translatesAutoresizingMaskIntoConstraints = false

        let repositoryHeader = FileMCPFeedbackComponents.pageHeader(
            title: "Repository Intelligence",
            description: "Observed read-only repository map, symbol and relation metadata. Provider completeness is heuristic and never grants authority or exhaustive source truth."
        )
        let repositoryTruth = NSStackView(views: [
            repositoryProviderLabel,
            repositorySummaryLabel,
            repositorySourceLabel,
        ])
        repositoryTruth.orientation = .vertical
        repositoryTruth.alignment = .leading
        repositoryTruth.spacing = 4

        let repositoryTables = NSStackView(views: [repositoryResultScroll, repositoryItemScroll])
        repositoryTables.orientation = .horizontal
        repositoryTables.alignment = .top
        repositoryTables.distribution = .fillEqually
        repositoryTables.spacing = 10
        repositoryTables.translatesAutoresizingMaskIntoConstraints = false

        let repositoryRoot = NSStackView(views: [
            repositoryHeader,
            repositoryTruth,
            repositoryTables,
            repositoryItemDetailLabel,
        ])
        repositoryRoot.orientation = .vertical
        repositoryRoot.alignment = .leading
        repositoryRoot.spacing = 8
        repositoryRoot.translatesAutoresizingMaskIntoConstraints = false

        let repositoryPage = NSView()
        repositoryPage.addSubview(repositoryRoot)
        NSLayoutConstraint.activate([
            repositoryRoot.leadingAnchor.constraint(equalTo: repositoryPage.leadingAnchor, constant: 12),
            repositoryRoot.trailingAnchor.constraint(equalTo: repositoryPage.trailingAnchor, constant: -12),
            repositoryRoot.topAnchor.constraint(equalTo: repositoryPage.topAnchor, constant: 12),
            repositoryRoot.bottomAnchor.constraint(equalTo: repositoryPage.bottomAnchor, constant: -12),
            repositoryResultScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            repositoryItemScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])

        let terminalSessionScroll = NSScrollView()
        terminalSessionScroll.documentView = terminalTableView
        terminalSessionScroll.hasVerticalScroller = true
        terminalSessionScroll.borderType = .bezelBorder
        terminalSessionScroll.translatesAutoresizingMaskIntoConstraints = false

        let terminalOutputScroll = NSScrollView()
        terminalOutputScroll.hasVerticalScroller = true
        terminalOutputScroll.hasHorizontalScroller = true
        terminalOutputScroll.autohidesScrollers = true
        terminalOutputScroll.borderType = .bezelBorder
        terminalOutputView.frame = terminalOutputScroll.contentView.bounds
        terminalOutputView.minSize = NSSize(width: 0, height: terminalOutputScroll.contentSize.height)
        terminalOutputView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        terminalOutputView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        terminalOutputView.textContainer?.widthTracksTextView = false
        terminalOutputScroll.documentView = terminalOutputView
        terminalOutputScroll.translatesAutoresizingMaskIntoConstraints = false

        let terminalHeader = FileMCPFeedbackComponents.pageHeader(
            title: "Terminal / PTY",
            description: "Live workspace-scoped PTY sessions. Output is read in bounded windows and is not copied into FileMCP activity or evidence telemetry."
        )
        let terminalTruth = NSStackView(views: [terminalBackendLabel, terminalPolicyLabel])
        terminalTruth.orientation = .vertical
        terminalTruth.alignment = .leading
        terminalTruth.spacing = 4

        let columnsLabel = NSTextField(labelWithString: "Cols")
        let rowsLabel = NSTextField(labelWithString: "Rows")
        let terminalControls = NSStackView(views: [
            terminalCtrlCButton,
            terminalStopButton,
            columnsLabel,
            terminalColumnsField,
            rowsLabel,
            terminalRowsField,
            terminalResizeButton,
        ])
        terminalControls.orientation = .horizontal
        terminalControls.alignment = .centerY
        terminalControls.spacing = 8
        terminalColumnsField.widthAnchor.constraint(equalToConstant: 54).isActive = true
        terminalRowsField.widthAnchor.constraint(equalToConstant: 54).isActive = true

        let terminalTables = NSStackView(views: [terminalSessionScroll, terminalOutputScroll])
        terminalTables.orientation = .horizontal
        terminalTables.alignment = .top
        terminalTables.distribution = .fillEqually
        terminalTables.spacing = 10
        terminalTables.translatesAutoresizingMaskIntoConstraints = false

        let terminalRoot = NSStackView(views: [
            terminalHeader,
            terminalTruth,
            terminalTables,
            terminalControls,
            terminalStatusLabel,
        ])
        terminalRoot.orientation = .vertical
        terminalRoot.alignment = .leading
        terminalRoot.spacing = 8
        terminalRoot.translatesAutoresizingMaskIntoConstraints = false

        let terminalPage = NSView()
        terminalPage.addSubview(terminalRoot)
        NSLayoutConstraint.activate([
            terminalRoot.leadingAnchor.constraint(equalTo: terminalPage.leadingAnchor, constant: 12),
            terminalRoot.trailingAnchor.constraint(equalTo: terminalPage.trailingAnchor, constant: -12),
            terminalRoot.topAnchor.constraint(equalTo: terminalPage.topAnchor, constant: 12),
            terminalRoot.bottomAnchor.constraint(equalTo: terminalPage.bottomAnchor, constant: -12),
            terminalSessionScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            terminalOutputScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
        ])

        let artifactBatchScroll = NSScrollView()
        artifactBatchScroll.documentView = artifactBatchTableView
        artifactBatchScroll.hasVerticalScroller = true
        artifactBatchScroll.borderType = .bezelBorder
        artifactBatchScroll.translatesAutoresizingMaskIntoConstraints = false

        let artifactEntryScroll = NSScrollView()
        artifactEntryScroll.documentView = artifactEntryTableView
        artifactEntryScroll.hasVerticalScroller = true
        artifactEntryScroll.borderType = .bezelBorder
        artifactEntryScroll.translatesAutoresizingMaskIntoConstraints = false

        let artifactHeader = FileMCPFeedbackComponents.pageHeader(
            title: "Artifacts & Batch",
            description: "Observed batch results and ContentRef metadata. Inline content and opaque ContentRef tokens are never copied into this view."
        )
        let artifactSummary = NSStackView(views: [artifactBatchSummaryLabel, artifactQuotaSummaryLabel])
        artifactSummary.orientation = .vertical
        artifactSummary.alignment = .leading
        artifactSummary.spacing = 4

        let artifactTables = NSStackView(views: [artifactBatchScroll, artifactEntryScroll])
        artifactTables.orientation = .horizontal
        artifactTables.alignment = .top
        artifactTables.distribution = .fillEqually
        artifactTables.spacing = 10
        artifactTables.translatesAutoresizingMaskIntoConstraints = false

        let artifactRoot = NSStackView(views: [
            artifactHeader,
            artifactSummary,
            artifactTables,
            artifactEntryDetailLabel,
        ])
        artifactRoot.orientation = .vertical
        artifactRoot.alignment = .leading
        artifactRoot.spacing = 8
        artifactRoot.translatesAutoresizingMaskIntoConstraints = false

        let artifactPage = NSView()
        artifactPage.addSubview(artifactRoot)
        NSLayoutConstraint.activate([
            artifactRoot.leadingAnchor.constraint(equalTo: artifactPage.leadingAnchor, constant: 12),
            artifactRoot.trailingAnchor.constraint(equalTo: artifactPage.trailingAnchor, constant: -12),
            artifactRoot.topAnchor.constraint(equalTo: artifactPage.topAnchor, constant: 12),
            artifactRoot.bottomAnchor.constraint(equalTo: artifactPage.bottomAnchor, constant: -12),
            artifactBatchScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            artifactEntryScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])

        let logPage = NSView()
        logPage.addSubview(logScroll)
        NSLayoutConstraint.activate([
            logScroll.leadingAnchor.constraint(equalTo: logPage.leadingAnchor, constant: 12),
            logScroll.trailingAnchor.constraint(equalTo: logPage.trailingAnchor, constant: -12),
            logScroll.topAnchor.constraint(equalTo: logPage.topAnchor, constant: 12),
            logScroll.bottomAnchor.constraint(equalTo: logPage.bottomAnchor, constant: -12),
        ])

        let homeHeader = FileMCPFeedbackComponents.pageHeader(
            title: "Home",
            description: "Operational health, active workspace and current gateway state.",
            status: .stopped
        )
        homeStatusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        homeWorkspaceLabel.textColor = .secondaryLabelColor
        homeRecentEventLabel.textColor = .secondaryLabelColor
        homeRecentEventLabel.maximumNumberOfLines = 2

        let quickConnections = NSButton(title: "Connections", target: self, action: #selector(showConnections))
        let quickSettings = NSButton(title: "Settings", target: self, action: #selector(showSettings))
        let quickActions = NSStackView(views: [quickConnections, quickSettings])
        quickActions.orientation = .horizontal
        quickActions.spacing = 8

        let homeContent = NSStackView(views: [
            homeHeader,
            NSTextField(labelWithString: "Runtime"),
            homeStatusLabel,
            NSTextField(labelWithString: "Active workspace"),
            homeWorkspaceLabel,
            NSTextField(labelWithString: "Latest important event"),
            homeRecentEventLabel,
            quickActions,
        ])
        homeContent.orientation = .vertical
        homeContent.alignment = .leading
        homeContent.spacing = 8
        homeContent.translatesAutoresizingMaskIntoConstraints = false

        let homePage = NSView()
        homePage.addSubview(homeContent)
        NSLayoutConstraint.activate([
            homeContent.leadingAnchor.constraint(equalTo: homePage.leadingAnchor, constant: 12),
            homeContent.trailingAnchor.constraint(lessThanOrEqualTo: homePage.trailingAnchor, constant: -12),
            homeContent.topAnchor.constraint(equalTo: homePage.topAnchor, constant: 12),
        ])

        workspaceRootLabel.maximumNumberOfLines = 2
        workspaceRootLabel.lineBreakMode = .byTruncatingMiddle
        workspaceStatusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        workspacePolicyLabel.textColor = .secondaryLabelColor
        workspaceConnectionLabel.textColor = .secondaryLabelColor

        let workspaceContent = NSStackView(views: [
            FileMCPFeedbackComponents.pageHeader(
                title: "Workspaces",
                description: "Configured root, health and policy context."
            ),
            NSTextField(labelWithString: "Root"),
            workspaceRootLabel,
            NSTextField(labelWithString: "Status"),
            workspaceStatusLabel,
            NSTextField(labelWithString: "Policy profile"),
            workspacePolicyLabel,
            NSTextField(labelWithString: "Connection"),
            workspaceConnectionLabel,
        ])
        workspaceContent.orientation = .vertical
        workspaceContent.alignment = .leading
        workspaceContent.spacing = 8
        workspaceContent.translatesAutoresizingMaskIntoConstraints = false

        let workspacesPage = NSView()
        workspacesPage.addSubview(workspaceContent)
        NSLayoutConstraint.activate([
            workspaceContent.leadingAnchor.constraint(equalTo: workspacesPage.leadingAnchor, constant: 12),
            workspaceContent.trailingAnchor.constraint(lessThanOrEqualTo: workspacesPage.trailingAnchor, constant: -12),
            workspaceContent.topAnchor.constraint(equalTo: workspacesPage.topAnchor, constant: 12),
        ])

        tabs.tabViewType = .noTabsNoBorder
        tabs.translatesAutoresizingMaskIntoConstraints = false
        tabs.delegate = self

        let homeTab = NSTabViewItem(identifier: "home")
        homeTab.label = "Home"
        homeTab.view = homePage

        let workspacesTab = NSTabViewItem(identifier: "workspaces")
        workspacesTab.label = "Workspaces"
        workspacesTab.view = workspacesPage

        let configTab = NSTabViewItem(identifier: "config")
        configTab.label = "Connection"
        configTab.view = connectionPage

        let settingsTab = NSTabViewItem(identifier: "settings")
        settingsTab.label = "Settings"
        settingsTab.view = settingsPage

        let activityTab = NSTabViewItem(identifier: "activity")
        activityTab.label = "Activity"
        activityTab.view = activityPage

        let changesTab = NSTabViewItem(identifier: "changes")
        changesTab.label = "Changes"
        changesTab.view = changesPage

        let evidenceTab = NSTabViewItem(identifier: "evidence")
        evidenceTab.label = "Evidence"
        evidenceTab.view = evidencePage

        let repositoryTab = NSTabViewItem(identifier: "repository")
        repositoryTab.label = "Repository"
        repositoryTab.view = repositoryPage

        let terminalTab = NSTabViewItem(identifier: "terminal")
        terminalTab.label = "Terminal"
        terminalTab.view = terminalPage

        let artifactTab = NSTabViewItem(identifier: "artifacts")
        artifactTab.label = "Artifacts"
        artifactTab.view = artifactPage

        let logTab = NSTabViewItem(identifier: "log")
        logTab.label = "Diagnostics"
        logTab.view = logPage

        tabs.addTabViewItem(homeTab)
        tabs.addTabViewItem(workspacesTab)
        tabs.addTabViewItem(configTab)
        tabs.addTabViewItem(settingsTab)
        tabs.addTabViewItem(activityTab)
        tabs.addTabViewItem(changesTab)
        tabs.addTabViewItem(evidenceTab)
        tabs.addTabViewItem(repositoryTab)
        tabs.addTabViewItem(terminalTab)
        tabs.addTabViewItem(artifactTab)
        tabs.addTabViewItem(logTab)
        tabs.selectTabViewItem(withIdentifier: "home")

        func navigationButton(_ title: String, action: Selector) -> NSButton {
            let button = NSButton(title: title, target: self, action: action)
            button.bezelStyle = .inline
            button.isBordered = false
            button.alignment = .left
            button.font = .systemFont(ofSize: 13, weight: .medium)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 132).isActive = true
            return button
        }

        let brandTitle = NSTextField(labelWithString: "FileMCP")
        brandTitle.font = .systemFont(ofSize: 18, weight: .semibold)
        let brandSubtitle = NSTextField(labelWithString: "Local agent gateway")
        brandSubtitle.font = .systemFont(ofSize: 10.5)
        brandSubtitle.textColor = .secondaryLabelColor

        shellStatusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        shellStatusLabel.textColor = .secondaryLabelColor
        shellStatusLabel.maximumNumberOfLines = 2

        let sidebar = NSStackView(views: [
            brandTitle,
            brandSubtitle,
            NSBox(),
            navigationButton("Home", action: #selector(showHome)),
            navigationButton("Workspaces", action: #selector(showWorkspaces)),
            navigationButton("Connections", action: #selector(showConnections)),
            navigationButton("Settings", action: #selector(showSettings)),
            navigationButton("Activity", action: #selector(showActivity)),
            navigationButton("Changes", action: #selector(showChanges)),
            navigationButton("Evidence", action: #selector(showEvidence)),
            navigationButton("Repository", action: #selector(showRepository)),
            navigationButton("Terminal", action: #selector(showTerminal)),
            navigationButton("Artifacts", action: #selector(showArtifacts)),
            navigationButton("Diagnostics", action: #selector(showDiagnostics)),
            NSView(),
            shellStatusLabel,
        ])
        sidebar.orientation = .vertical
        sidebar.alignment = .leading
        sidebar.spacing = 8
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        sidebar.setContentHuggingPriority(.required, for: .horizontal)
        sidebar.setContentCompressionResistancePriority(.required, for: .horizontal)

        let shell = NSStackView(views: [sidebar, tabs])
        shell.orientation = .horizontal
        shell.alignment = .top
        shell.spacing = 0
        shell.translatesAutoresizingMaskIntoConstraints = false

        let footerDivider = NSBox()
        footerDivider.boxType = .separator
        footerDivider.translatesAutoresizingMaskIntoConstraints = false

        let quitHint = NSTextField(labelWithString: "Quit the app and stop the tunnel if it is running.")
        quitHint.font = .systemFont(ofSize: 10.5)
        quitHint.textColor = .secondaryLabelColor
        quitHint.setContentHuggingPriority(.defaultLow, for: .horizontal)
        quitHint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let quitRow = NSStackView(views: [quitHint, quitButton])
        quitRow.orientation = .horizontal
        quitRow.alignment = .centerY
        quitRow.spacing = 10
        quitRow.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(footerDivider)
        footer.addSubview(quitRow)

        view.addSubview(shell)
        view.addSubview(footer)
        NSLayoutConstraint.activate([
            shell.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            shell.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            shell.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            shell.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -8),
            sidebar.widthAnchor.constraint(equalToConstant: 156),
            tabs.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.contentWidth + 24),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: Layout.footerHeight),
            footerDivider.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 24),
            footerDivider.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -24),
            footerDivider.topAnchor.constraint(equalTo: footer.topAnchor),
            quitRow.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 24),
            quitRow.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -24),
            quitRow.topAnchor.constraint(equalTo: footerDivider.bottomAnchor, constant: 9),
            saveSettingsButton.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            connectionRoot.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            settingsForm.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            tunnelIDField.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            apiKeyField.widthAnchor.constraint(equalToConstant: Layout.contentWidth),
            profileField.widthAnchor.constraint(equalToConstant: Layout.fieldWidth),
            portField.widthAnchor.constraint(equalToConstant: Layout.fieldWidth),
            directoryField.widthAnchor.constraint(equalToConstant: Layout.directoryFieldWidth),
            chooseButton.widthAnchor.constraint(equalToConstant: Layout.directoryButtonWidth),
            healthAddressField.widthAnchor.constraint(equalToConstant: Layout.fieldWidth),
            gitUserNameField.widthAnchor.constraint(equalToConstant: Layout.fieldWidth),
            gitUserEmailField.widthAnchor.constraint(equalToConstant: Layout.fieldWidth),
            execEnvironmentAllowListField.widthAnchor.constraint(equalToConstant: Layout.fieldWidth),
        ])
    }

    private func configure(_ field: NSTextField, placeholder: String) {
        field.placeholderString = placeholder
        field.controlSize = .regular
        field.isEditable = true
        field.isSelectable = true
        field.translatesAutoresizingMaskIntoConstraints = false
        (field as? NSSecureTextField)?.usesSingleLineMode = true
    }

    private func loadConfiguration() {
        let defaults = UserDefaults.standard
        tunnelIDField.stringValue = defaults.string(forKey: ConfigKey.tunnelID) ?? ""
        apiKeyField.stringValue = ""
        updateAPIKeyPlaceholder()
        updatePolicyExplanation()
        profileField.stringValue = defaults.string(forKey: ConfigKey.profile) ?? "filemcp"
        portField.stringValue = defaults.string(forKey: ConfigKey.port) ?? "8008"
        directoryField.stringValue = defaults.string(forKey: ConfigKey.allowedDirectory) ?? defaultDirectory()
        healthAddressField.stringValue = defaults.string(forKey: ConfigKey.healthAddress) ?? "127.0.0.1:0"
        gitUserNameField.stringValue = defaults.string(forKey: ConfigKey.gitUserName) ?? ""
        gitUserEmailField.stringValue = defaults.string(forKey: ConfigKey.gitUserEmail) ?? ""
        execEnvironmentAllowListField.stringValue = (defaults.stringArray(forKey: ConfigKey.execEnvironmentAllowList) ?? []).joined(separator: ", ")
        let storedPolicy = defaults.string(forKey: ConfigKey.policyProfile)
        let policyProfile = storedPolicy ?? (defaults.bool(forKey: ConfigKey.enableCommands)
            ? FileMCPPolicyProfiles.legacyCommandCompatible
            : FileMCPPolicyProfiles.restricted)
        if let index = policyProfilePopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == policyProfile }) {
            policyProfilePopup.selectItem(at: index)
        } else {
            policyProfilePopup.selectItem(at: 0)
        }
        enableCommandsCheckbox.state = policyProfile == FileMCPPolicyProfiles.legacyCommandCompatible ? .on : .off
    }

    private func updateAPIKeyPlaceholder() {
        let hasSavedKey = storage.hasSavedAPIKey
        apiKeyField.placeholderString = hasSavedKey ? "Saved - leave blank to keep it" : "sk-..."
        apiKeyStatusLabel.stringValue = hasSavedKey ? "API key is saved in Keychain" : "No API key is saved"
        deleteKeyButton.isEnabled = hasSavedKey
        refreshConnectionDiagnostics()
    }

    private func defaultDirectory() -> String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/FileMCP", isDirectory: true).path
    }

    private func saveConnectionConfiguration() {
        UserDefaults.standard.set(tunnelIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: ConfigKey.tunnelID)
    }

    private func saveSettingsConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(profileField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: ConfigKey.profile)
        defaults.set(portField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: ConfigKey.port)
        defaults.set(directoryField.stringValue, forKey: ConfigKey.allowedDirectory)
        defaults.set(healthAddressField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: ConfigKey.healthAddress)
        defaults.set(gitUserNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: ConfigKey.gitUserName)
        defaults.set(gitUserEmailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: ConfigKey.gitUserEmail)
        defaults.set(execEnvironmentAllowList(), forKey: ConfigKey.execEnvironmentAllowList)
        let policyProfile = policyProfilePopup.selectedItem?.representedObject as? String ?? FileMCPPolicyProfiles.restricted
        defaults.set(policyProfile, forKey: ConfigKey.policyProfile)
        defaults.set(policyProfile == FileMCPPolicyProfiles.legacyCommandCompatible, forKey: ConfigKey.enableCommands)
    }

    private func execEnvironmentAllowList() -> [String] {
        execEnvironmentAllowListField.stringValue
            .components(separatedBy: CharacterSet(charactersIn: ",;\r\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func dockerExecutionBackendConfiguration() -> DockerExecutionBackendConfiguration? {
        let defaults = UserDefaults.standard
        let mode = defaults.string(forKey: ConfigKey.executionBackendMode)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "host"
        guard mode == "docker" else { return nil }

        func intValue(_ key: String, fallback: Int) -> Int {
            defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
        }
        func doubleValue(_ key: String, fallback: Double) -> Double {
            defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
        }

        let memoryMB = intValue(ConfigKey.dockerMemoryMB, fallback: 2048)
        let memoryBytes: Int64 = (128...65_536).contains(memoryMB)
            ? Int64(memoryMB) * 1024 * 1024
            : -1
        return DockerExecutionBackendConfiguration(
            enabled: true,
            image: defaults.string(forKey: ConfigKey.dockerImage) ?? "",
            allowedImages: defaults.stringArray(forKey: ConfigKey.dockerAllowedImages) ?? [],
            networkEnabled: defaults.bool(forKey: ConfigKey.dockerNetworkEnabled),
            cpuLimit: doubleValue(ConfigKey.dockerCpuLimit, fallback: 2.0),
            memoryBytes: memoryBytes,
            pidsLimit: intValue(ConfigKey.dockerPidsLimit, fallback: 128),
            user: defaults.string(forKey: ConfigKey.dockerUser) ?? "1000:1000",
            startupTimeoutSeconds: intValue(ConfigKey.dockerStartupTimeoutSeconds, fallback: 30),
            idleTTLSeconds: intValue(ConfigKey.dockerIdleTTLSeconds, fallback: 900),
            maxLifetimeSeconds: intValue(ConfigKey.dockerMaxLifetimeSeconds, fallback: 7200)
        )
    }

    private func localPolicyConfiguration() -> LocalPolicyConfiguration {
        let defaults = UserDefaults.standard
        let profile = policyProfilePopup.selectedItem?.representedObject as? String ?? FileMCPPolicyProfiles.restricted
        return LocalPolicyConfiguration(
            profile: profile,
            customMaxRisk: defaults.string(forKey: ConfigKey.customPolicyMaxRisk) ?? "low",
            customAllowedEffects: defaults.stringArray(forKey: ConfigKey.customPolicyAllowedEffects) ?? ["read", "metadata"],
            customAllowNetworkOpenWorld: defaults.bool(forKey: ConfigKey.customPolicyAllowNetworkOpenWorld),
            customAllowShell: defaults.bool(forKey: ConfigKey.customPolicyAllowShell)
        )
    }

    private func saveAllConfiguration() {
        saveConnectionConfiguration()
        saveSettingsConfiguration()
    }

    @objc private func showHome() {
        tabs.selectTabViewItem(withIdentifier: "home")
    }

    @objc private func showWorkspaces() {
        refreshWorkspaceSummary()
        tabs.selectTabViewItem(withIdentifier: "workspaces")
    }

    @objc private func showConnections() {
        tabs.selectTabViewItem(withIdentifier: "config")
    }

    @objc private func policyProfileChanged() {
        updatePolicyExplanation()
    }

    private func updatePolicyExplanation() {
        let profile = policyProfilePopup.selectedItem?.representedObject as? String ?? FileMCPPolicyProfiles.restricted
        switch profile {
        case FileMCPPolicyProfiles.restricted:
            policyExplanationLabel.stringValue = "Restricted keeps the legacy-safe surface and does not grant shell or open-world network authority."
        case FileMCPPolicyProfiles.workspaceAuto:
            policyExplanationLabel.stringValue = "Workspace auto enables the safe workspace-oriented capability set while keeping shell and open-world network tools disabled."
        case FileMCPPolicyProfiles.custom:
            policyExplanationLabel.stringValue = "Custom uses explicit local policy configuration; server-owned policy remains authoritative."
        case FileMCPPolicyProfiles.legacyCommandCompatible:
            policyExplanationLabel.stringValue = "Legacy command compatible is retained only for migrated configurations and cannot be selected for new policy changes."
        default:
            policyExplanationLabel.stringValue = "Policy is owned by local settings and enforced by the server."
        }
    }

    @objc private func showSettings() {
        tabs.selectTabViewItem(withIdentifier: "settings")
    }

    @objc private func showActivity() {
        refreshActivityFilter()
        tabs.selectTabViewItem(withIdentifier: "activity")
    }

    @objc private func activityFilterChanged() {
        refreshActivityFilter()
    }

    private func refreshActivityFilter() {
        let selected = activityFilterPopup.indexOfSelectedItem
        filteredActivityEvents = activityEvents.filter { event in
            switch selected {
            case 1: return event.kind == "Error"
            case 2: return event.kind == "Runtime"
            case 3: return event.kind == "Settings"
            default: return true
            }
        }.reversed()
        activityTableView.reloadData()
        if activityTableView.selectedRow >= filteredActivityEvents.count {
            activityTableView.deselectAll(nil)
            activityDetailLabel.stringValue = "Select an activity event."
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == activityTableView { return filteredActivityEvents.count }
        if tableView == changesTableView { return changeEvents.count }
        if tableView == evidenceTableView { return evidenceEvents.count }
        if tableView == repositoryResultTableView { return repositoryEvents.count }
        if tableView == repositoryItemTableView { return selectedRepositoryEvent?.entries.count ?? 0 }
        if tableView == terminalTableView { return terminalSessions.count }
        if tableView == artifactBatchTableView { return artifactBatchEvents.count }
        if tableView == artifactEntryTableView { return selectedArtifactBatch?.entries.count ?? 0 }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == repositoryResultTableView {
            guard row >= 0, row < repositoryEvents.count, let tableColumn else { return nil }
            let event = repositoryEvents[repositoryEvents.count - 1 - row]
            let text: String
            switch tableColumn.identifier.rawValue {
            case "repository-time":
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                text = formatter.string(from: event.timestamp)
            case "repository-workspace": text = event.workspace
            case "repository-query": text = event.queryKind
            case "repository-count": text = event.totalCount > 0 ? "\(event.returnedCount)/\(event.totalCount)" : "\(event.returnedCount)"
            default: text = event.partial || event.truncated || event.displayTruncated ? "Partial" : "Observed"
            }
            let label = NSTextField(labelWithString: text)
            label.lineBreakMode = .byTruncatingTail
            return label
        }

        if tableView == repositoryItemTableView {
            guard let result = selectedRepositoryEvent, row >= 0, row < result.entries.count, let tableColumn else { return nil }
            let entry = result.entries[row]
            let text: String
            switch tableColumn.identifier.rawValue {
            case "repository-item-path": text = entry.path
            case "repository-item-name": text = entry.name
            case "repository-item-kind": text = entry.kind
            case "repository-item-detail": text = entry.detail
            default: text = entry.score
            }
            let label = NSTextField(labelWithString: text)
            label.lineBreakMode = .byTruncatingTail
            return label
        }

        if tableView == terminalTableView {
            guard row >= 0, row < terminalSessions.count, let tableColumn else { return nil }
            let session = terminalSessions[row]
            let text: String
            switch tableColumn.identifier.rawValue {
            case "terminal-state": text = session.state
            case "terminal-pid": text = session.pid.map(String.init) ?? "-"
            case "terminal-session": text = session.sessionID
            default:
                if session.lastActivityEpochMs > 0 {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss"
                    text = formatter.string(from: Date(timeIntervalSince1970: Double(session.lastActivityEpochMs) / 1000.0))
                } else {
                    text = "-"
                }
            }
            let label = NSTextField(labelWithString: text)
            label.lineBreakMode = .byTruncatingTail
            return label
        }

        if tableView == artifactBatchTableView {
            guard row >= 0, row < artifactBatchEvents.count, let tableColumn else { return nil }
            let event = artifactBatchEvents[artifactBatchEvents.count - 1 - row]
            let text: String
            switch tableColumn.identifier.rawValue {
            case "artifact-time":
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                text = formatter.string(from: event.timestamp)
            case "artifact-workspace": text = event.workspace
            case "artifact-operation": text = event.operation
            case "artifact-completed": text = "\(event.completedCount)/\(event.requestedCount)"
            default:
                text = event.cancelled ? "Cancelled" : event.partial ? "Partial" : event.truncated ? "Truncated" : "Complete"
            }
            let label = NSTextField(labelWithString: text)
            label.lineBreakMode = .byTruncatingTail
            return label
        }

        if tableView == artifactEntryTableView {
            guard let batch = selectedArtifactBatch,
                  row >= 0,
                  row < batch.entries.count,
                  let tableColumn else { return nil }
            let entry = batch.entries[row]
            let text: String
            switch tableColumn.identifier.rawValue {
            case "artifact-entry-path": text = entry.path
            case "artifact-entry-state": text = entry.state
            case "artifact-entry-delivery": text = entry.delivery
            case "artifact-entry-size":
                text = entry.sizeBytes.map { "\($0) B" } ?? "N/A"
            default:
                if let expiry = entry.expiresEpochMs {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MM-dd HH:mm"
                    text = formatter.string(from: Date(timeIntervalSince1970: Double(expiry) / 1000.0))
                } else {
                    text = "N/A"
                }
            }
            let label = NSTextField(labelWithString: text)
            label.lineBreakMode = .byTruncatingTail
            return label
        }

        if tableView == evidenceTableView {
            guard row >= 0, row < evidenceEvents.count, let tableColumn else { return nil }
            let event = evidenceEvents[evidenceEvents.count - 1 - row]
            let text: String
            switch tableColumn.identifier.rawValue {
            case "evidence-time":
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                text = formatter.string(from: event.timestamp)
            case "evidence-state": text = event.verificationState == "not-applicable" ? "N/A" : event.verificationState
            case "evidence-workspace": text = event.workspace
            case "evidence-criterion": text = event.criterion
            default: text = event.evidenceID
            }
            let label = NSTextField(labelWithString: text)
            label.lineBreakMode = .byTruncatingTail
            return label
        }

        if tableView == changesTableView {
            guard row >= 0, row < changeEvents.count, let tableColumn else { return nil }
            let event = changeEvents[changeEvents.count - 1 - row]
            let text: String
            switch tableColumn.identifier.rawValue {
            case "change-time":
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                text = formatter.string(from: event.timestamp)
            case "change-status": text = event.status
            case "change-workspace": text = event.workspace
            case "change-operation": text = event.operation
            default: text = event.summary
            }
            let label = NSTextField(labelWithString: text)
            label.lineBreakMode = .byTruncatingTail
            return label
        }

        guard tableView == activityTableView,
              row >= 0,
              row < filteredActivityEvents.count,
              let tableColumn else { return nil }

        let event = filteredActivityEvents[row]
        let text: String
        switch tableColumn.identifier.rawValue {
        case "activity-time":
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            text = formatter.string(from: event.timestamp)
        case "activity-type": text = event.kind
        case "activity-workspace": text = event.workspace
        default: text = event.summary
        }

        let label = NSTextField(labelWithString: text)
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }

        if table === repositoryResultTableView {
            let row = repositoryResultTableView.selectedRow
            guard row >= 0, row < repositoryEvents.count else {
                selectedRepositoryEvent = nil
                repositoryItemTableView.reloadData()
                repositoryProviderLabel.stringValue = "Select a captured repository-intelligence result."
                repositorySummaryLabel.stringValue = "No synthetic repository state is shown."
                repositorySourceLabel.stringValue = "Source state: not observed"
                repositoryItemDetailLabel.stringValue = "Select an observed repository result."
                return
            }

            let event = repositoryEvents[repositoryEvents.count - 1 - row]
            selectedRepositoryEvent = event
            repositoryItemTableView.reloadData()
            repositoryItemTableView.deselectAll(nil)
            repositoryProviderLabel.stringValue =
                "\(event.providerID) \(event.providerVersion) | completeness=\(event.completeness) | grants_authority=\(event.grantsAuthority) | raw_source_persisted=\(event.rawSourcePersisted)"
            var flags: [String] = []
            if event.partial { flags.append("partial") }
            if event.truncated { flags.append("truncated:\(event.truncationReason ?? "unknown")") }
            if event.displayTruncated { flags.append("display-bounded") }
            if event.ambiguous { flags.append("ambiguous") }
            let state = flags.isEmpty ? "observed" : flags.joined(separator: ", ")
            repositorySummaryLabel.stringValue =
                "\(event.queryKind): \(event.returnedCount)/\(event.totalCount) returned | \(state) | \(event.entries.count) metadata row(s) displayed | symbol_support=\(event.symbolSupport) | artifact_state=\(event.artifactState). Provider completeness is descriptive, not exhaustive truth."
            repositorySourceLabel.stringValue = "Source state: \(event.sourceStateID)"
            repositoryItemDetailLabel.stringValue = "Observed metadata only; raw source, cursors and opaque ContentRef tokens are not copied into this view."
            return
        }

        if table === repositoryItemTableView {
            guard let result = selectedRepositoryEvent else {
                repositoryItemDetailLabel.stringValue = "Select an observed repository result."
                return
            }
            let row = repositoryItemTableView.selectedRow
            guard row >= 0, row < result.entries.count else {
                repositoryItemDetailLabel.stringValue = "Select a metadata row."
                return
            }
            let entry = result.entries[row]
            repositoryItemDetailLabel.stringValue =
                "Path: \(entry.path) | Name/language: \(entry.name) | Kind: \(entry.kind) | \(entry.detail) | Score: \(entry.score.isEmpty ? "N/A" : entry.score)"
            return
        }

        if table === terminalTableView {
            guard !terminalRefreshInProgress else { return }
            guard let session = selectedTerminalSession() else {
                terminalBackendLabel.stringValue = "No live PTY session observed."
                setTerminalControlsEnabled(false)
                return
            }
            terminalReadCursors.removeValue(forKey: session.sessionID)
            terminalOutputView.string = ""
            updateTerminalSelection(session)
            readTerminalOutput(session)
            return
        }

        if table === artifactBatchTableView {
            let row = artifactBatchTableView.selectedRow
            guard row >= 0, row < artifactBatchEvents.count else {
                selectedArtifactBatch = nil
                artifactEntryTableView.reloadData()
                artifactBatchSummaryLabel.stringValue = "Select a captured batch result."
                artifactQuotaSummaryLabel.stringValue = "Quota usage remaining is not emitted by batch results."
                artifactEntryDetailLabel.stringValue = "Select a captured batch entry."
                return
            }

            let event = artifactBatchEvents[artifactBatchEvents.count - 1 - row]
            selectedArtifactBatch = event
            artifactEntryTableView.reloadData()
            artifactEntryTableView.deselectAll(nil)

            var flags: [String] = []
            if event.partial { flags.append("partial") }
            if event.cancelled { flags.append("cancelled") }
            if event.truncated { flags.append("truncated:\(event.truncationReason ?? "unknown")") }
            let state = flags.isEmpty ? "complete" : flags.joined(separator: ", ")
            artifactBatchSummaryLabel.stringValue =
                "\(event.operation): \(event.completedCount)/\(event.requestedCount) completed | \(state) | \(event.entries.count) emitted entries."
            artifactQuotaSummaryLabel.stringValue =
                "\(event.contentRefCount) ContentRef delivery item(s); \(event.quotaErrorCount) observed artifact quota error(s). Remaining quota is not emitted by the batch result."
            return
        }

        if table === artifactEntryTableView {
            guard let batch = selectedArtifactBatch else {
                artifactEntryDetailLabel.stringValue = "Select a captured batch entry."
                return
            }
            let row = artifactEntryTableView.selectedRow
            guard row >= 0, row < batch.entries.count else {
                artifactEntryDetailLabel.stringValue = "Select a captured batch entry."
                return
            }

            let entry = batch.entries[row]
            let contentRef = entry.contentRefPresent ? "Present (opaque token redacted)" : "Not present"
            let expiry: String
            if let expiryMs = entry.expiresEpochMs {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                expiry = formatter.string(from: Date(timeIntervalSince1970: Double(expiryMs) / 1000.0))
            } else {
                expiry = "N/A"
            }
            artifactEntryDetailLabel.stringValue =
                "Path: \(entry.path)\n" +
                "State: \(entry.state)\n" +
                "Delivery: \(entry.delivery)\n" +
                "Size: \(entry.sizeBytes.map { "\($0) B" } ?? "N/A")\n" +
                "Max inline bytes: \(entry.maxBytes.map { "\($0) B" } ?? "N/A")\n" +
                "Version strength: \(entry.versionStrength ?? "N/A")\n" +
                "ContentRef: \(contentRef)\n" +
                "Expires: \(expiry)\n" +
                "Blob ID: \(entry.blobID ?? "N/A")\n" +
                "Error: \(entry.errorCode ?? "N/A")\n" +
                "Message: \(entry.message ?? "N/A")"
            return
        }

        if table === evidenceTableView {
            let row = evidenceTableView.selectedRow
            guard row >= 0, row < evidenceEvents.count else {
                evidenceDetailLabel.stringValue = "Select an evidence record."
                return
            }
            let event = evidenceEvents[evidenceEvents.count - 1 - row]
            let state = event.verificationState == "not-applicable" ? "N/A" : event.verificationState
            evidenceDetailLabel.stringValue =
                "Evidence: \(event.evidenceID)\n" +
                "Operation: \(event.operationID) (\(event.operationState))\n" +
                "Criterion: \(event.criterion)\n" +
                "Verification: \(state)\n" +
                "Storage: \(event.storageStatus)\n" +
                "Source binding: \(event.sourceBinding)\n" +
                "Source state: \(event.sourceStateID ?? "N/A")\n" +
                "Project context: \(event.projectContextDigest ?? "N/A")\n" +
                "Policy hash: \(event.policyHash)\n" +
                "Catalog: \(event.catalogVersion) | \(event.catalogHash)\n" +
                "Block reason: \(event.blockReason ?? "N/A")"
            return
        }
        if table === changesTableView {
            let row = changesTableView.selectedRow
            guard row >= 0, row < changeEvents.count else {
                changesDetailLabel.stringValue = "Select a captured mutation event."
                return
            }
            let event = changeEvents[changeEvents.count - 1 - row]
            changesDetailLabel.stringValue = "\(event.status) | \(event.operation) | \(event.workspace)\nFile/version context: not emitted by runtime event\n\n\(event.detail)"
            return
        }
        guard table === activityTableView else { return }
        let row = activityTableView.selectedRow
        guard row >= 0, row < filteredActivityEvents.count else {
            activityDetailLabel.stringValue = "Select an activity event."
            return
        }
        let event = filteredActivityEvents[row]
        activityDetailLabel.stringValue = "\(event.kind) | \(event.workspace)\n\(event.detail)"
    }

    private func captureRepositoryIntelligenceEvent(from line: String, workspace: String) {
        let marker = "[RepositoryIntelligenceResult] "
        guard let range = line.range(of: marker) else { return }
        let jsonText = String(line[range.upperBound...])
        guard let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        func text(_ key: String, fallback: String = "unknown") -> String {
            (object[key] as? String) ?? fallback
        }
        func integer(_ key: String) -> Int {
            (object[key] as? NSNumber)?.intValue ?? 0
        }
        func bool(_ key: String) -> Bool {
            (object[key] as? NSNumber)?.boolValue ?? false
        }

        let queryKind = text("query_kind", fallback: "repository")
        var entries: [RepositoryItemEvent] = []
        if let rawEntries = object["entries"] as? [[String: Any]] {
            for entry in rawEntries {
                let path = (entry["path"] as? String) ?? "(unknown)"
                let name = (entry["name"] as? String) ?? (entry["language"] as? String) ?? ""
                let kind = (entry["kind"] as? String) ?? (queryKind == "repo_map" ? "file" : "")
                let detail: String
                if queryKind == "repo_map" {
                    detail = "language=\((entry["language"] as? String) ?? "unknown") | size=\((entry["size_bytes"] as? NSNumber)?.intValue ?? 0) B | symbols=\((entry["symbol_count"] as? NSNumber)?.intValue ?? 0) | imports=\((entry["import_count"] as? NSNumber)?.intValue ?? 0) | relations=\((entry["relation_count"] as? NSNumber)?.intValue ?? 0) | supported=\((entry["supported_language"] as? NSNumber)?.boolValue ?? false)"
                } else if queryKind == "symbol_search" {
                    detail = "line=\((entry["line"] as? NSNumber)?.intValue ?? 0)"
                } else if queryKind == "related_files" {
                    detail = "direction=\((entry["direction"] as? String) ?? "unknown")"
                } else {
                    detail = "Observed metadata"
                }
                let score = (entry["score"] as? NSNumber).map { String(format: "%.3f", $0.doubleValue) } ?? ""
                entries.append(RepositoryItemEvent(path: path, name: name, kind: kind, detail: detail, score: score))
            }
        }

        var total = integer("total_items")
        if total == 0 { total = integer("total_results") }
        repositoryEvents.append(RepositoryResultEvent(
            timestamp: Date(),
            workspace: workspace,
            queryKind: queryKind,
            providerID: text("provider_id"),
            providerVersion: text("provider_version"),
            completeness: text("completeness"),
            sourceStateID: text("source_state_id"),
            grantsAuthority: bool("grants_authority"),
            rawSourcePersisted: bool("raw_source_persisted"),
            partial: bool("partial"),
            truncated: bool("truncated") || bool("generation_truncated"),
            truncationReason: (object["truncation_reason"] as? String) ?? (object["generation_truncation_reason"] as? String),
            returnedCount: integer("returned_count"),
            totalCount: total,
            symbolSupport: bool("symbol_support"),
            ambiguous: bool("ambiguous"),
            displayTruncated: bool("display_truncated"),
            artifactState: text("artifact_state", fallback: "none"),
            entries: entries
        ))
    }

    private func captureArtifactBatchEvent(from line: String, workspace: String) {
        let marker = "[ArtifactBatchResult] "
        guard let range = line.range(of: marker) else { return }
        let jsonText = String(line[range.upperBound...])
        guard let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        func text(_ key: String, fallback: String = "unknown") -> String {
            (object[key] as? String) ?? fallback
        }
        func integer(_ key: String) -> Int {
            (object[key] as? NSNumber)?.intValue ?? 0
        }
        func bool(_ key: String) -> Bool {
            (object[key] as? NSNumber)?.boolValue ?? false
        }
        func optionalText(_ source: [String: Any], _ key: String) -> String? {
            source[key] as? String
        }
        func optionalInt64(_ source: [String: Any], _ key: String) -> Int64? {
            (source[key] as? NSNumber)?.int64Value
        }

        var entries: [ArtifactBatchEntryEvent] = []
        if let rawEntries = object["entries"] as? [[String: Any]] {
            for entry in rawEntries {
                entries.append(ArtifactBatchEntryEvent(
                    path: (entry["path"] as? String) ?? "(unknown)",
                    state: (entry["state"] as? String) ?? "unknown",
                    delivery: (entry["delivery"] as? String) ?? "none",
                    sizeBytes: optionalInt64(entry, "size_bytes"),
                    maxBytes: optionalInt64(entry, "max_bytes"),
                    versionStrength: optionalText(entry, "version_strength"),
                    expiresEpochMs: optionalInt64(entry, "expires_epoch_ms"),
                    blobID: optionalText(entry, "blob_id"),
                    contentRefPresent: (entry["content_ref_present"] as? NSNumber)?.boolValue ?? false,
                    errorCode: optionalText(entry, "error_code"),
                    message: optionalText(entry, "message")
                ))
            }
        }

        artifactBatchEvents.append(ArtifactBatchEvent(
            timestamp: Date(),
            workspace: workspace,
            operation: text("operation", fallback: "batch"),
            requestedCount: integer("requested_count"),
            completedCount: integer("completed_count"),
            partial: bool("partial"),
            cancelled: bool("cancelled"),
            truncated: bool("truncated"),
            truncationReason: object["truncation_reason"] as? String,
            contentRefCount: integer("content_ref_count"),
            quotaErrorCount: integer("quota_error_count"),
            entries: entries
        ))
    }

    private func captureEvidenceEvent(from line: String, workspace: String) {
        let marker = "[EvidenceResult] "
        guard let range = line.range(of: marker) else { return }
        let jsonText = String(line[range.upperBound...])
        guard let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        func text(_ key: String, fallback: String = "unknown") -> String {
            (object[key] as? String) ?? fallback
        }
        func optionalText(_ key: String) -> String? {
            object[key] as? String
        }

        evidenceEvents.append(EvidenceEvent(
            timestamp: Date(),
            workspace: workspace,
            evidenceID: text("evidence_id"),
            operationID: text("operation_id"),
            criterion: text("criterion_id"),
            verificationState: text("verification_state"),
            operationState: text("operation_state"),
            storageStatus: text("storage_status"),
            sourceBinding: text("source_binding"),
            sourceStateID: optionalText("source_state_id"),
            projectContextDigest: optionalText("project_context_digest"),
            policyHash: text("policy_hash"),
            catalogHash: text("catalog_hash"),
            catalogVersion: text("catalog_version"),
            blockReason: optionalText("block_reason")
        ))
    }

    private func changeEvent(from line: String, workspace: String) -> ChangeEvent? {
        let lower = line.lowercased()
        let operation: String
        if lower.contains("apply_edits") { operation = "apply_edits" }
        else if lower.contains("write_file") { operation = "write_file" }
        else if lower.contains("delete_file") { operation = "delete_file" }
        else if lower.contains("delete_directory") { operation = "delete_directory" }
        else { return nil }

        let status: String
        if lower.contains("changed since") || lower.contains("stale") { status = "Stale" }
        else if lower.contains("conflict") || lower.contains("overlapping") { status = "Conflict" }
        else if lower.contains("error") || lower.contains("failed") || lower.contains("refused") { status = "Failed" }
        else { status = "Applied" }

        let summary = line.count <= 160 ? line : String(line.prefix(157)) + "..."
        return ChangeEvent(timestamp: Date(), status: status, workspace: workspace, operation: operation, summary: summary, detail: line)
    }

    private func recordActivity(_ text: String) {
        for rawLine in text.split(whereSeparator: { $0.isNewline }) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            var workspace = "Global"
            if line.hasPrefix("["), let close = line.firstIndex(of: "]") {
                workspace = String(line[line.index(after: line.startIndex)..<close])
            }

            let lower = line.lowercased()
            let kind: String
            if lower.contains("error") || lower.contains("failed") || lower.contains("could not") {
                kind = "Error"
            } else if lower.contains("settings") || lower.contains("connection") {
                kind = "Settings"
            } else if lower.contains("runtime") || lower.contains("tunnel") || workspace != "Global" {
                kind = "Runtime"
            } else {
                kind = "System"
            }

            captureEvidenceEvent(from: line, workspace: workspace)
            captureRepositoryIntelligenceEvent(from: line, workspace: workspace)
            captureArtifactBatchEvent(from: line, workspace: workspace)
            let summary = line.count <= 140 ? line : String(line.prefix(137)) + "..."
            activityEvents.append(ActivityEvent(timestamp: Date(), kind: kind, workspace: workspace, summary: summary, detail: line))
            if let change = changeEvent(from: line, workspace: workspace) {
                changeEvents.append(change)
            }
        }

        if activityEvents.count > maxActivityEvents {
            activityEvents.removeFirst(activityEvents.count - maxActivityEvents)
        }
        if changeEvents.count > maxChangeEvents {
            changeEvents.removeFirst(changeEvents.count - maxChangeEvents)
        }
        if evidenceEvents.count > maxEvidenceEvents {
            evidenceEvents.removeFirst(evidenceEvents.count - maxEvidenceEvents)
        }
        if repositoryEvents.count > maxRepositoryEvents {
            repositoryEvents.removeFirst(repositoryEvents.count - maxRepositoryEvents)
        }
        if artifactBatchEvents.count > maxArtifactBatchEvents {
            artifactBatchEvents.removeFirst(artifactBatchEvents.count - maxArtifactBatchEvents)
        }
        if tabs.selectedTabViewItem?.identifier as? String == "activity" {
            refreshActivityFilter()
        }
        if tabs.selectedTabViewItem?.identifier as? String == "changes" {
            changesTableView.reloadData()
        }
        if tabs.selectedTabViewItem?.identifier as? String == "evidence" {
            evidenceTableView.reloadData()
        }
        if tabs.selectedTabViewItem?.identifier as? String == "repository" {
            repositoryResultTableView.reloadData()
            if selectedRepositoryEvent != nil { repositoryItemTableView.reloadData() }
        }
        if tabs.selectedTabViewItem?.identifier as? String == "artifacts" {
            artifactBatchTableView.reloadData()
            if selectedArtifactBatch != nil { artifactEntryTableView.reloadData() }
        }
    }

    @objc private func showChanges() {
        changesTableView.reloadData()
        tabs.selectTabViewItem(withIdentifier: "changes")
    }

    @objc private func showEvidence() {
        evidenceTableView.reloadData()
        tabs.selectTabViewItem(withIdentifier: "evidence")
    }

    @objc private func showRepository() {
        repositoryResultTableView.reloadData()
        if selectedRepositoryEvent != nil { repositoryItemTableView.reloadData() }
        tabs.selectTabViewItem(withIdentifier: "repository")
    }

    @objc private func showTerminal() {
        tabs.selectTabViewItem(withIdentifier: "terminal")
        refreshTerminal(readSelectedOutput: true)
        if terminalTimer == nil {
            terminalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self,
                      (self.tabs.selectedTabViewItem?.identifier as? String) == "terminal" else { return }
                self.refreshTerminal(readSelectedOutput: true)
            }
        }
    }

    private func refreshTerminal(readSelectedOutput: Bool) {
        guard !terminalRefreshInProgress else { return }
        terminalRefreshInProgress = true
        defer { terminalRefreshInProgress = false }

        guard runtime.state == .running else {
            terminalSessions.removeAll()
            terminalTableView.reloadData()
            terminalTableView.deselectAll(nil)
            terminalBackendLabel.stringValue = "No live PTY session observed."
            terminalPolicyLabel.stringValue = "Workspace runtime is not connected."
            terminalStatusLabel.stringValue = "0 observed PTY sessions | restart resume unsupported"
            setTerminalControlsEnabled(false)
            return
        }

        let priorID = selectedTerminalSession()?.sessionID
        do {
            let policy = try runtime.presentationPolicyMetadata()
            let result = try runtime.callPresentationPtyTool(name: "pty_list", arguments: [:])
            let backendID = terminalString(result, "backend_id", fallback: "unknown")
            let backendVersion = terminalString(result, "backend_version", fallback: "unknown")
            let backendCapabilities = terminalStringList(result, "backend_capabilities")
            let profile = terminalString(policy, "profile", fallback: "unknown")
            let generation = terminalInt64(policy, "generation")
            let policyHash = terminalString(policy, "hash", fallback: "unknown")
            let sessions = result["sessions"] as? [[String: Any]] ?? []

            terminalSessions = sessions.compactMap { session in
                let sessionID = terminalString(session, "session_id")
                guard !sessionID.isEmpty else { return nil }
                return TerminalSessionEvent(
                    sessionID: sessionID,
                    pid: terminalInt(session, "pid"),
                    state: terminalString(session, "state", fallback: "unknown"),
                    lastActivityEpochMs: terminalInt64(session, "last_activity_epoch_ms"),
                    earliestCursor: terminalString(session, "earliest_cursor"),
                    endCursor: terminalString(session, "end_cursor"),
                    exitCode: terminalInt(session, "exit_code"),
                    spillRefCount: terminalInt(session, "spill_ref_count") ?? 0,
                    actualPTY: terminalBool(session, "actual_pty"),
                    restartResumeSupported: terminalBool(session, "restart_resume_supported"),
                    grantsAuthority: terminalBool(session, "grants_authority"),
                    backendID: backendID,
                    backendVersion: backendVersion,
                    backendCapabilities: backendCapabilities,
                    policyProfile: profile,
                    policyGeneration: generation,
                    policyHash: policyHash
                )
            }.sorted { lhs, rhs in
                if lhs.lastActivityEpochMs == rhs.lastActivityEpochMs { return lhs.sessionID < rhs.sessionID }
                return lhs.lastActivityEpochMs > rhs.lastActivityEpochMs
            }

            terminalTableView.reloadData()
            let selectedIndex = priorID.flatMap { id in terminalSessions.firstIndex { $0.sessionID == id } }
                ?? (terminalSessions.isEmpty ? nil : 0)
            if let selectedIndex {
                terminalTableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
                let selected = terminalSessions[selectedIndex]
                if priorID != selected.sessionID {
                    terminalReadCursors.removeValue(forKey: selected.sessionID)
                    terminalOutputView.string = ""
                }
                updateTerminalSelection(selected)
                if readSelectedOutput { readTerminalOutput(selected) }
            } else {
                terminalTableView.deselectAll(nil)
                terminalBackendLabel.stringValue = "No live PTY session observed."
                terminalPolicyLabel.stringValue = "profile=\(profile) | generation=\(generation) | presentation_grants_authority=false"
                setTerminalControlsEnabled(false)
            }
            terminalStatusLabel.stringValue = "\(terminalSessions.count) observed PTY session(s) | bounded read=\(terminalReadWindowBytes / 1024) KiB | restart resume unsupported"
        } catch {
            terminalSessions.removeAll()
            terminalTableView.reloadData()
            terminalTableView.deselectAll(nil)
            terminalBackendLabel.stringValue = "PTY backend unavailable."
            terminalPolicyLabel.stringValue = "Policy/runtime state unavailable without expanding authority."
            terminalStatusLabel.stringValue = "PTY unavailable: \(error.localizedDescription)"
            setTerminalControlsEnabled(false)
        }
    }

    private func readTerminalOutput(_ session: TerminalSessionEvent) {
        do {
            let cursor = terminalReadCursors[session.sessionID] ?? session.earliestCursor
            let result = try runtime.callPresentationPtyTool(name: "pty_read", arguments: [
                "session_id": session.sessionID,
                "cursor": cursor,
                "max_bytes": terminalReadWindowBytes,
            ])
            if terminalBool(result, "cursor_evicted") {
                terminalOutputView.string = "[Older PTY output was evicted from the bounded runtime buffer.]\n"
            }
            let text = terminalString(result, "text")
            if !text.isEmpty { appendTerminalOutput(text) }
            let nextCursor = terminalString(result, "next_cursor", fallback: cursor)
            if !nextCursor.isEmpty { terminalReadCursors[session.sessionID] = nextCursor }
        } catch {
            terminalStatusLabel.stringValue = "PTY output unavailable: \(error.localizedDescription)"
        }
    }

    private func appendTerminalOutput(_ text: String) {
        var combined = terminalOutputView.string + text
        if combined.count > maxTerminalOutputCharacters {
            combined = String(combined.suffix(maxTerminalOutputCharacters))
        }
        terminalOutputView.string = combined
        terminalOutputView.scrollToEndOfDocument(nil)
    }

    private func selectedTerminalSession() -> TerminalSessionEvent? {
        let row = terminalTableView.selectedRow
        guard row >= 0, row < terminalSessions.count else { return nil }
        return terminalSessions[row]
    }

    private func updateTerminalSelection(_ session: TerminalSessionEvent) {
        let exitText = session.exitCode.map(String.init) ?? "-"
        terminalBackendLabel.stringValue = "\(session.backendID) \(session.backendVersion) | capabilities=\(session.backendCapabilities) | state=\(session.state) | pid=\(session.pid.map(String.init) ?? "-") | exit=\(exitText) | actual_pty=\(session.actualPTY) | restart_resume_supported=\(session.restartResumeSupported) | grants_authority=\(session.grantsAuthority)"
        let hash = session.policyHash.count > 16 ? String(session.policyHash.prefix(16)) + "..." : session.policyHash
        terminalPolicyLabel.stringValue = "profile=\(session.policyProfile) | generation=\(session.policyGeneration) | hash=\(hash) | presentation_grants_authority=false"
        setTerminalControlsEnabled(session.isControllable)
    }

    private func setTerminalControlsEnabled(_ enabled: Bool) {
        terminalCtrlCButton.isEnabled = enabled
        terminalStopButton.isEnabled = enabled
        terminalResizeButton.isEnabled = enabled
    }

    @objc private func terminalSendCtrlC() {
        guard let session = selectedTerminalSession() else { return }
        executeTerminalControl(session, tool: "pty_signal", arguments: ["session_id": session.sessionID, "signal": "ctrl_c"], success: "Ctrl+C sent")
    }

    @objc private func terminalStopSession() {
        guard let session = selectedTerminalSession() else { return }
        executeTerminalControl(session, tool: "pty_stop", arguments: ["session_id": session.sessionID], success: "PTY session stopped")
    }

    @objc private func terminalResizeSession() {
        guard let session = selectedTerminalSession(),
              let columns = Int(terminalColumnsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              let rows = Int(terminalRowsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...500).contains(columns),
              (1...300).contains(rows) else {
            terminalStatusLabel.stringValue = "Resize requires columns 1..500 and rows 1..300."
            return
        }
        executeTerminalControl(session, tool: "pty_resize", arguments: [
            "session_id": session.sessionID,
            "columns": columns,
            "rows": rows,
        ], success: "PTY resized to \(columns)x\(rows)")
    }

    private func executeTerminalControl(_ session: TerminalSessionEvent, tool: String, arguments: [String: Any], success: String) {
        do {
            _ = try runtime.callPresentationPtyTool(name: tool, arguments: arguments)
            terminalStatusLabel.stringValue = "\(success) | \(session.sessionID)"
            refreshTerminal(readSelectedOutput: false)
        } catch {
            terminalStatusLabel.stringValue = "PTY control blocked/unavailable: \(error.localizedDescription)"
        }
    }

    private func terminalString(_ object: [String: Any], _ key: String, fallback: String = "") -> String {
        object[key] as? String ?? fallback
    }

    private func terminalInt(_ object: [String: Any], _ key: String) -> Int? {
        if object[key] is NSNull { return nil }
        return (object[key] as? NSNumber)?.intValue
    }

    private func terminalInt64(_ object: [String: Any], _ key: String) -> Int64 {
        (object[key] as? NSNumber)?.int64Value ?? 0
    }

    private func terminalBool(_ object: [String: Any], _ key: String) -> Bool {
        (object[key] as? NSNumber)?.boolValue ?? false
    }

    private func terminalStringList(_ object: [String: Any], _ key: String) -> String {
        if let values = object[key] as? [String] { return values.joined(separator: ",") }
        if let values = object[key] as? [Any] { return values.compactMap { $0 as? String }.joined(separator: ",") }
        return "none"
    }

    @objc private func showArtifacts() {
        artifactBatchTableView.reloadData()
        if selectedArtifactBatch != nil { artifactEntryTableView.reloadData() }
        tabs.selectTabViewItem(withIdentifier: "artifacts")
    }

    @objc private func showDiagnostics() {
        tabs.selectTabViewItem(withIdentifier: "log")
        flushLogBuffer()
    }

    @objc private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose directory"
        if panel.runModal() == .OK, let url = panel.url { directoryField.stringValue = url.path }
    }

    @objc private func startTunnel() {
        switch runtime.state {
        case .running, .starting, .restarting, .cooldown:
            runtime.stop()
            return
        case .stopping:
            return
        case .stopped, .failed:
            break
        }
        guard validateConnectionConfiguration(requireAPIKey: true), validateSettingsConfiguration() else { return }
        do {
            let typedKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !typedKey.isEmpty {
                try storage.saveAPIKey(typedKey)
                apiKeyField.stringValue = ""
                updateAPIKeyPlaceholder()
            }
            let apiKey = try storage.readAPIKey()
            saveAllConfiguration()
            guard let port = UInt16(portField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                showError("The MCP port is invalid.")
                return
            }
            appendLog("[Runtime] Connect requested.\n")
            let policyConfiguration = try localPolicyConfiguration().normalized()
            runtime.start(LocalMCPConfiguration(
                tunnelID: tunnelIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: apiKey,
                profile: profileField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                port: port,
                allowedDirectory: directoryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                healthAddress: healthAddressField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                gitUserName: gitUserNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                gitUserEmail: gitUserEmailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                enableCommands: policyConfiguration.profile == FileMCPPolicyProfiles.legacyCommandCompatible,
                policyConfiguration: policyConfiguration,
                execEnvironmentAllowList: execEnvironmentAllowList(),
                dockerExecutionBackend: dockerExecutionBackendConfiguration()
            ))
        } catch { showError(error.localizedDescription) }
    }

    @objc private func saveConnectionOnly() {
        guard validateConnectionConfiguration(requireAPIKey: true) else { return }
        saveConnectionButton.setLoading(true)
        do {
            let typedKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !typedKey.isEmpty {
                try storage.saveAPIKey(typedKey)
                apiKeyField.stringValue = ""
                updateAPIKeyPlaceholder()
            }
            saveConnectionConfiguration()
            appendLog("[Runtime] Connection settings saved.\n")
            if runtime.state != .stopped { appendLog("[Runtime] Changes will take effect the next time the tunnel starts.\n") }
            finishLoading(saveConnectionButton)
        } catch {
            saveConnectionButton.setLoading(false)
            showError(error.localizedDescription)
        }
    }

    @objc private func saveSettingsOnly() {
        guard validateSettingsConfiguration() else { return }
        saveSettingsButton.setLoading(true)
        saveSettingsConfiguration()
        appendLog("[Runtime] Settings saved.\n")
        if runtime.state != .stopped { appendLog("[Runtime] Changes will take effect the next time the tunnel starts.\n") }
        finishLoading(saveSettingsButton)
    }

    private func finishLoading(_ button: LoadingButton) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak button] in button?.setLoading(false) }
    }

    private func validateConnectionConfiguration(requireAPIKey: Bool) -> Bool {
        let tunnelID = tunnelIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let typedKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tunnelID.isEmpty else { showError("Enter a Tunnel ID in the Connection tab."); return false }
        guard LocalMCPRuntime.isValidTunnelID(tunnelID) else { showError("Tunnel ID must match tunnel_<32 lowercase letters or digits>."); return false }
        if requireAPIKey && typedKey.isEmpty && !storage.hasSavedAPIKey { showError("Enter a Runtime API key in the Connection tab."); return false }
        return true
    }

    private func validateSettingsConfiguration() -> Bool {
        let profile = profileField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = portField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = directoryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !directory.isEmpty else { tabs.selectTabViewItem(withIdentifier: "settings"); showError("Choose a shared directory."); return false }
        guard !profile.isEmpty else { tabs.selectTabViewItem(withIdentifier: "settings"); setAdvancedSettingsExpanded(true); showError("Profile cannot be empty."); return false }
        guard LocalMCPRuntime.isValidProfileName(profile) else { tabs.selectTabViewItem(withIdentifier: "settings"); setAdvancedSettingsExpanded(true); showError("Profile must start with a letter or number and contain only letters, numbers, '.', '_' or '-' (maximum 128 characters)."); return false }
        guard let portNumber = UInt16(port), portNumber > 0 else { tabs.selectTabViewItem(withIdentifier: "settings"); setAdvancedSettingsExpanded(true); showError("MCP port must be between 1 and 65535."); return false }
        let healthAddress = healthAddressField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LocalMCPRuntime.normalizedHealthAddress(healthAddress) != nil else { tabs.selectTabViewItem(withIdentifier: "settings"); setAdvancedSettingsExpanded(true); showError("Health listener must use localhost, 127.0.0.1, or [::1] with a port from 0 to 65535."); return false }
        do {
            _ = try ExecProcessEnvironmentAuthority.normalizePatterns(execEnvironmentAllowList())
        } catch {
            tabs.selectTabViewItem(withIdentifier: "settings")
            setAdvancedSettingsExpanded(true)
            showError(error.localizedDescription)
            return false
        }
        return true
    }

    func showSettingsTab() { tabs.selectTabViewItem(withIdentifier: "settings") }
    func shutdownForTermination() {
        terminalTimer?.invalidate()
        terminalTimer = nil
        runtime.shutdownImmediately()
    }

    @objc private func deleteSavedKey() {
        do {
            try storage.deleteAPIKey()
            apiKeyField.stringValue = ""
            updateAPIKeyPlaceholder()
        } catch { showError(error.localizedDescription) }
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
    @objc private func toggleAdvancedSettings() { setAdvancedSettingsExpanded(advancedSettingsGroup.isHidden) }

    private func setAdvancedSettingsExpanded(_ expanded: Bool) {
        advancedSettingsGroup.isHidden = !expanded
        advancedToggleButton.image = advancedChevron(expanded: expanded)
        let settingsSelected = tabs.selectedTabViewItem?.identifier as? String == "settings"
        resizeWindowForAdvancedSettings(expanded: expanded && settingsSelected)
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        let settingsSelected = tabViewItem?.identifier as? String == "settings"
        resizeWindowForAdvancedSettings(expanded: settingsSelected && !advancedSettingsGroup.isHidden)
        if tabViewItem?.identifier as? String == "log" { flushLogBuffer() }
    }

    private func resizeWindowForAdvancedSettings(expanded: Bool) {
        guard let window = view.window else { return }
        let targetContentHeight = expanded ? Layout.expandedWindowHeight : Layout.collapsedWindowHeight
        var contentRect = window.contentRect(forFrameRect: window.frame)
        guard abs(contentRect.height - targetContentHeight) > 0.5 else { return }
        let topEdge = window.frame.maxY
        contentRect.size.height = targetContentHeight
        var targetFrame = window.frameRect(forContentRect: contentRect)
        targetFrame.origin.x = window.frame.origin.x
        targetFrame.origin.y = topEdge - targetFrame.height
        window.setFrame(targetFrame, display: true, animate: true)
    }

    private func advancedChevron(expanded: Bool) -> NSImage? {
        NSImage(systemSymbolName: expanded ? "chevron.down" : "chevron.right", accessibilityDescription: expanded ? "Collapse advanced options" : "Expand advanced options")
    }

    private func configureRuntime() {
        runtime.onLog = { [weak self] text in
            DispatchQueue.main.async { self?.appendLog(text) }
        }
        runtime.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.updateRunButton(state: state)
                if case let .failed(message) = state { self?.showError(message) }
            }
        }
    }

    private func refreshConnectionDiagnostics() {
        let hasKey = storage.hasSavedAPIKey
        let tunnel = tunnelIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch runtime.state {
        case .stopped:
            connectionStatusLabel.stringValue = "Runtime stopped"
        case .failed:
            connectionStatusLabel.stringValue = "Runtime failed"
        case .starting:
            connectionStatusLabel.stringValue = "Connecting"
        case .running:
            connectionStatusLabel.stringValue = "Connected"
        case .restarting:
            connectionStatusLabel.stringValue = "Reconnecting"
        case .cooldown:
            connectionStatusLabel.stringValue = "Reconnect cooldown"
        case .stopping:
            connectionStatusLabel.stringValue = "Disconnecting"
        }
        connectionDiagnosticsLabel.stringValue =
            "\(tunnel.isEmpty ? "No tunnel ID configured" : "Tunnel ID configured"); " +
            (hasKey ? "credential stored securely in Keychain." : "credential missing.")
    }

    private func refreshWorkspaceSummary() {
        let root = directoryField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        workspaceRootLabel.stringValue = root.isEmpty ? "Not configured" : root
        workspacePolicyLabel.stringValue = policyProfilePopup.titleOfSelectedItem ?? "Default"

        switch runtime.state {
        case .stopped:
            workspaceStatusLabel.stringValue = "Stopped"
            workspaceConnectionLabel.stringValue = "Disconnected"
        case .failed:
            workspaceStatusLabel.stringValue = "Failed"
            workspaceConnectionLabel.stringValue = "Attention required"
        case .starting:
            workspaceStatusLabel.stringValue = "Starting"
            workspaceConnectionLabel.stringValue = "Connecting"
        case .running:
            workspaceStatusLabel.stringValue = "Healthy"
            workspaceConnectionLabel.stringValue = "Connected"
        case .restarting:
            workspaceStatusLabel.stringValue = "Reconnecting"
            workspaceConnectionLabel.stringValue = "Connected"
        case .cooldown:
            workspaceStatusLabel.stringValue = "Cooldown"
            workspaceConnectionLabel.stringValue = "Waiting to reconnect"
        case .stopping:
            workspaceStatusLabel.stringValue = "Stopping"
            workspaceConnectionLabel.stringValue = "Disconnecting"
        }
    }

    private func refreshHomeSummary(state: LocalMCPRuntimeState) {
        homeWorkspaceLabel.stringValue = directoryField.stringValue.isEmpty ? "No workspace selected" : directoryField.stringValue
        homeRecentEventLabel.stringValue = lastImportantEvent
        switch state {
        case .stopped: homeStatusLabel.stringValue = "Runtime stopped"
        case .failed: homeStatusLabel.stringValue = "Runtime failed"
        case .starting: homeStatusLabel.stringValue = "Runtime starting"
        case .running: homeStatusLabel.stringValue = "Runtime connected"
        case .restarting: homeStatusLabel.stringValue = "Runtime reconnecting"
        case .cooldown: homeStatusLabel.stringValue = "Reconnect cooldown"
        case .stopping: homeStatusLabel.stringValue = "Runtime stopping"
        }
    }

    private func updateRunButton(state: LocalMCPRuntimeState) {
        refreshHomeSummary(state: state)
        refreshWorkspaceSummary()
        refreshConnectionDiagnostics()
        switch state {
        case .stopped:
            startButton.title = "Connect"; startButton.bezelColor = .controlAccentColor; startButton.isEnabled = true
            shellStatusLabel.stringValue = "Runtime stopped"
        case .failed:
            startButton.title = "Connect"; startButton.bezelColor = .controlAccentColor; startButton.isEnabled = true
            shellStatusLabel.stringValue = "Runtime failed"
        case .starting:
            startButton.title = "ConnectingÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦"; startButton.bezelColor = .controlAccentColor; startButton.isEnabled = false
            shellStatusLabel.stringValue = "Runtime starting"
        case .running:
            startButton.title = "Disconnect"; startButton.bezelColor = .systemRed; startButton.isEnabled = true
            shellStatusLabel.stringValue = "Runtime connected"
        case .restarting:
            startButton.title = "Disconnect"; startButton.bezelColor = .systemRed; startButton.isEnabled = true
            shellStatusLabel.stringValue = "Runtime reconnecting"
        case .cooldown:
            startButton.title = "Disconnect"; startButton.bezelColor = .systemRed; startButton.isEnabled = true
            shellStatusLabel.stringValue = "Reconnect cooldown"
        case .stopping:
            startButton.title = "DisconnectingÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦"; startButton.bezelColor = .systemRed; startButton.isEnabled = false
            shellStatusLabel.stringValue = "Runtime stopping"
        }
        startButton.contentTintColor = .white
    }

    private func appendLog(_ text: String) {
        recordActivity(text)
        logBuffer += text
        if logBuffer.count > maxLogCharacters {
            let overflow = logBuffer.count - maxLogCharacters
            let cut = logBuffer.index(logBuffer.startIndex, offsetBy: overflow)
            logBuffer = "[...older log truncated...]\n" + String(logBuffer[cut...])
        }
        guard !logFlushScheduled else { return }
        logFlushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.flushLogBuffer() }
    }

    private func flushLogBuffer() {
        logFlushScheduled = false
        logView.string = logBuffer
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.textColor = .white
        logView.scrollToEndOfDocument(nil)
        logView.needsDisplay = true
    }

    private func showError(_ message: String) {
        lastImportantEvent = message
        homeRecentEventLabel.stringValue = message
        let alert = NSAlert()
        alert.messageText = appName
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var controller: MainViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MainViewController()
        self.controller = controller
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Layout.windowWidth, height: Layout.collapsedWindowHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = appName
        window.contentViewController = controller
        window.setContentSize(NSSize(width: Layout.windowWidth, height: Layout.collapsedWindowHeight))
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        configureMainMenu()
        showMainWindow()
    }

    @objc private func showMainWindow() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func showSettingsWindow() {
        showMainWindow()
        controller?.showSettingsTab()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: appName)
        let aboutItem = NSMenuItem(title: "About FileMCP", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        aboutItem.target = NSApp
        appMenu.addItem(aboutItem)
        let settingsItem = NSMenuItem(title: "SettingsÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦", action: #selector(showSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)
        appMenu.addItem(.separator())
        let hideItem = NSMenuItem(title: "Hide FileMCP", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.target = NSApp
        appMenu.addItem(hideItem)
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.target = NSApp
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        let showAllItem = NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        showAllItem.target = NSApp
        appMenu.addItem(showAllItem)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit FileMCP", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(.separator())
        let frontItem = NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        frontItem.target = NSApp
        windowMenu.addItem(frontItem)
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdownForTermination()
    }
}
