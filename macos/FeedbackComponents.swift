import AppKit

enum FileMCPPresentationDataState { case firstLoad, refreshing, ready, empty, partial, error, stale }
enum FileMCPNotificationSurface { case toast, inline, persistent, dialog }

struct FileMCPPresentationFeedback {
    let severity: FileMCPPresentationSeverity
    let title: String
    let message: String
    let actionLabel: String?
    let technicalDetail: String?
    let correlationReference: String?

    init(severity: FileMCPPresentationSeverity, title: String, message: String, actionLabel: String? = nil, technicalDetail: String? = nil, correlationReference: String? = nil) {
        self.severity = severity
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.technicalDetail = technicalDetail
        self.correlationReference = correlationReference
    }
}

enum FileMCPNotificationPolicy {
    static func surface(severity: FileMCPPresentationSeverity, blocksProgress: Bool, requiresDecision: Bool, isPersistentState: Bool) -> FileMCPNotificationSurface {
        if requiresDecision { return .dialog }
        if isPersistentState { return .persistent }
        if blocksProgress || severity == .warning || severity == .danger || severity == .stale { return .inline }
        return .toast
    }
}

enum FileMCPFeedbackComponents {
    static func statusBadge(_ status: FileMCPPresentationStatus) -> NSTextField {
        let descriptor = FileMCPPresentationStatusCatalog.describe(status)
        let label = NSTextField(labelWithString: descriptor.label)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = FileMCPPresentationStatusCatalog.color(descriptor.severity)
        label.wantsLayer = true
        label.layer?.cornerRadius = 7
        label.layer?.borderWidth = 1
        label.layer?.borderColor = label.textColor.cgColor
        label.layer?.backgroundColor = label.textColor.withAlphaComponent(0.08).cgColor
        label.alignment = .center
        label.setAccessibilityLabel("\(descriptor.label) status")
        return label
    }

    static func inlineNotice(_ feedback: FileMCPPresentationFeedback) -> NSView {
        let title = NSTextField(labelWithString: feedback.title)
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = FileMCPPresentationStatusCatalog.color(feedback.severity)
        let message = NSTextField(wrappingLabelWithString: feedback.message)
        let stack = NSStackView(views: [title, message])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 8
        stack.layer?.borderWidth = 1
        stack.layer?.borderColor = title.textColor.cgColor
        stack.setAccessibilityLabel("\(feedback.title). \(feedback.message)")
        return stack
    }

    static func emptyState(title: String, message: String, actionTitle: String? = nil, target: AnyObject? = nil, action: Selector? = nil) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.alignment = .center
        let messageLabel = NSTextField(wrappingLabelWithString: message)
        messageLabel.alignment = .center
        messageLabel.textColor = .secondaryLabelColor
        var views: [NSView] = [titleLabel, messageLabel]
        if let actionTitle, let action {
            let button = NSButton(title: actionTitle, target: target, action: action)
            views.append(button)
        }
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setAccessibilityLabel("\(title). \(message)")
        return stack
    }

    static func pageHeader(title: String, description: String?, status: FileMCPPresentationStatus? = nil) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 26, weight: .semibold)
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.addArrangedSubview(titleLabel)
        if let description, !description.isEmpty {
            let descriptionLabel = NSTextField(wrappingLabelWithString: description)
            descriptionLabel.textColor = .secondaryLabelColor
            textStack.addArrangedSubview(descriptionLabel)
        }
        let row = NSStackView(views: [textStack])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12
        if let status { row.addArrangedSubview(statusBadge(status)) }
        row.setAccessibilityLabel(title)
        return row
    }
}
