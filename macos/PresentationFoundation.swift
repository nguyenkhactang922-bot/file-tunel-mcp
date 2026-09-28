import AppKit

enum FileMCPPresentationStatus: CaseIterable {
    case healthy
    case connected
    case starting
    case running
    case stopping
    case stopped
    case degraded
    case warning
    case blocked
    case failed
    case stale
    case verifying
    case passed
    case cancelled
    case expired
    case unavailable
}

enum FileMCPPresentationSeverity {
    case neutral
    case info
    case success
    case warning
    case danger
    case stale
}

struct FileMCPPresentationStatusDescriptor {
    let status: FileMCPPresentationStatus
    let label: String
    let severity: FileMCPPresentationSeverity
    let iconKey: String
}

enum FileMCPPresentationStatusCatalog {
    static func describe(_ status: FileMCPPresentationStatus) -> FileMCPPresentationStatusDescriptor {
        switch status {
        case .healthy: return .init(status: status, label: "Healthy", severity: .success, iconKey: "status-success")
        case .connected: return .init(status: status, label: "Connected", severity: .success, iconKey: "status-success")
        case .starting: return .init(status: status, label: "Starting", severity: .info, iconKey: "status-progress")
        case .running: return .init(status: status, label: "Running", severity: .info, iconKey: "status-running")
        case .stopping: return .init(status: status, label: "Stopping", severity: .info, iconKey: "status-progress")
        case .stopped: return .init(status: status, label: "Stopped", severity: .neutral, iconKey: "status-stopped")
        case .degraded: return .init(status: status, label: "Degraded", severity: .warning, iconKey: "status-warning")
        case .warning: return .init(status: status, label: "Warning", severity: .warning, iconKey: "status-warning")
        case .blocked: return .init(status: status, label: "Blocked", severity: .warning, iconKey: "status-blocked")
        case .failed: return .init(status: status, label: "Failed", severity: .danger, iconKey: "status-error")
        case .stale: return .init(status: status, label: "Stale", severity: .stale, iconKey: "status-stale")
        case .verifying: return .init(status: status, label: "Verifying", severity: .info, iconKey: "status-progress")
        case .passed: return .init(status: status, label: "Passed", severity: .success, iconKey: "status-success")
        case .cancelled: return .init(status: status, label: "Cancelled", severity: .neutral, iconKey: "status-cancelled")
        case .expired: return .init(status: status, label: "Expired", severity: .stale, iconKey: "status-expired")
        case .unavailable: return .init(status: status, label: "Unavailable", severity: .neutral, iconKey: "status-unavailable")
        }
    }

    static func color(_ severity: FileMCPPresentationSeverity) -> NSColor {
        switch severity {
        case .info: return .systemBlue
        case .success: return .systemGreen
        case .warning: return .systemOrange
        case .danger: return .systemRed
        case .stale: return .systemPurple
        case .neutral: return .secondaryLabelColor
        }
    }
}

enum FileMCPNavigationDestination: Int, CaseIterable {
    case home
    case workspaces
    case activity
    case changes
    case repository
    case terminal
    case recovery
    case evidence
    case connections
    case settings

    var label: String {
        switch self {
        case .home: return "Home"
        case .workspaces: return "Workspaces"
        case .activity: return "Activity"
        case .changes: return "Changes"
        case .repository: return "Repository"
        case .terminal: return "Terminal"
        case .recovery: return "Recovery"
        case .evidence: return "Evidence"
        case .connections: return "Connections"
        case .settings: return "Settings"
        }
    }

    var iconKey: String {
        switch self {
        case .home: return "nav-home"
        case .workspaces: return "nav-workspaces"
        case .activity: return "nav-activity"
        case .changes: return "nav-changes"
        case .repository: return "nav-repository"
        case .terminal: return "nav-terminal"
        case .recovery: return "nav-recovery"
        case .evidence: return "nav-evidence"
        case .connections: return "nav-connections"
        case .settings: return "nav-settings"
        }
    }
}
