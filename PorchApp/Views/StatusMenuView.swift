import Cocoa

/// Hover-tracking button with a rounded highlight background.
private class HoverButton: NSButton {
    var hoverBackgroundColor: NSColor = .white.withAlphaComponent(0.08)
    private var isHovering = false
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovering {
            hoverBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        }
        super.draw(dirtyRect)
    }
}

/// Custom NSView for the combined status row in the dropdown menu.
///
/// Layout:
///   [●] 192.168.2.150          [⟲] [▶] [●] Disconnected
///   device dot + IP             auto  play  conn dot + state
///
/// The device side highlights on hover (clickable → device info).
/// The play/stop and auto-reconnect buttons have individual hover states.
class StatusMenuView: NSView {
    // Device side
    private let deviceDot = NSView()
    private let deviceLabel = NSTextField(labelWithString: "")
    private var deviceTrackingArea: NSTrackingArea?
    private var deviceHovering = false

    // Connection side
    private let connectionDot = NSView()
    private let connectionLabel = NSTextField(labelWithString: "")
    private let toggleButton = HoverButton()
    private let autoReconnectButton = HoverButton()

    var onToggleConnection: (() -> Void)?
    var onToggleAutoReconnect: (() -> Void)?
    var onDeviceClick: (() -> Void)?

    private var autoReconnect = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Device dot
        deviceDot.wantsLayer = true
        deviceDot.layer?.cornerRadius = 4
        addSubview(deviceDot)

        // Device label
        deviceLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        deviceLabel.textColor = .secondaryLabelColor
        deviceLabel.isSelectable = false
        addSubview(deviceLabel)

        // Auto-reconnect button
        autoReconnectButton.bezelStyle = .inline
        autoReconnectButton.isBordered = false
        autoReconnectButton.imagePosition = .imageOnly
        autoReconnectButton.image = NSImage(systemSymbolName: "arrow.clockwise.circle.fill", accessibilityDescription: "Auto-reconnect")
        autoReconnectButton.contentTintColor = .systemGray
        autoReconnectButton.target = self
        autoReconnectButton.action = #selector(autoReconnectTapped)
        autoReconnectButton.toolTip = "Auto-reconnect"
        addSubview(autoReconnectButton)

        // Toggle button (play/stop)
        toggleButton.bezelStyle = .inline
        toggleButton.isBordered = false
        toggleButton.imagePosition = .imageOnly
        toggleButton.target = self
        toggleButton.action = #selector(toggleTapped)
        addSubview(toggleButton)

        // Connection dot
        connectionDot.wantsLayer = true
        connectionDot.layer?.cornerRadius = 4
        addSubview(connectionDot)

        // Connection label
        connectionLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        connectionLabel.textColor = .labelColor
        connectionLabel.isSelectable = false
        addSubview(connectionLabel)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = deviceTrackingArea { removeTrackingArea(existing) }
        // Track the left half of the view for device hover
        let leftHalf = NSRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height)
        deviceTrackingArea = NSTrackingArea(
            rect: leftHalf,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        )
        addTrackingArea(deviceTrackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        deviceHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        deviceHovering = false
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if loc.x < bounds.width / 2 && deviceHovering {
            onDeviceClick?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Draw hover highlight on the device side
        if deviceHovering {
            NSColor.white.withAlphaComponent(0.06).setFill()
            let leftRect = NSRect(x: 4, y: 2, width: bounds.width / 2 - 4, height: bounds.height - 4)
            NSBezierPath(roundedRect: leftRect, xRadius: 6, yRadius: 6).fill()
        }
    }

    func update(
        deviceFound: Bool,
        deviceIP: String?,
        connectionState: ConnectionState,
        canConnect: Bool,
        autoReconnect: Bool
    ) {
        self.autoReconnect = autoReconnect

        // Device side
        deviceDot.layer?.backgroundColor = (deviceFound ? NSColor.systemGreen : NSColor.systemRed).cgColor
        deviceLabel.stringValue = deviceIP ?? "No device"

        // Connection side
        let connColor: NSColor
        let connText: String
        switch connectionState {
        case .connected:
            connColor = .systemYellow
            connText = "Connected"
        case .connecting:
            connColor = .systemOrange
            connText = "Connecting..."
        case .disconnected:
            connColor = .systemGray
            connText = "Disconnected"
        }
        connectionDot.layer?.backgroundColor = connColor.cgColor
        connectionLabel.stringValue = connText
        connectionLabel.textColor = connectionState == .disconnected ? .secondaryLabelColor : .labelColor

        // Toggle button: play when disconnected, stop when connected/connecting
        let isOff = connectionState == .disconnected
        let iconName = isOff ? "play.fill" : "stop.fill"
        let iconColor: NSColor = isOff ? .systemGreen : .systemRed
        toggleButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: isOff ? "Connect" : "Disconnect")
        toggleButton.contentTintColor = iconColor
        toggleButton.isEnabled = canConnect
        toggleButton.isHidden = !canConnect
        toggleButton.toolTip = isOff ? "Connect" : "Disconnect"

        // Auto-reconnect button
        autoReconnectButton.contentTintColor = autoReconnect ? .systemBlue : .systemGray
        autoReconnectButton.toolTip = autoReconnect ? "Auto-reconnect: On" : "Auto-reconnect: Off"

        needsLayout = true
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        let dotSize: CGFloat = 8
        let padding: CGFloat = 14
        let midY = h / 2
        let iconSize: CGFloat = 18

        // Left side: device dot + label
        deviceDot.frame = NSRect(x: padding, y: midY - dotSize / 2, width: dotSize, height: dotSize)
        deviceLabel.sizeToFit()
        deviceLabel.frame.origin = NSPoint(x: padding + dotSize + 6, y: midY - deviceLabel.frame.height / 2)

        // Right side (right-aligned): [auto-reconnect] [play/stop] [dot] [label]
        let rightEdge = bounds.width - padding

        connectionLabel.sizeToFit()
        let labelX = rightEdge - connectionLabel.frame.width
        connectionLabel.frame.origin = NSPoint(x: labelX, y: midY - connectionLabel.frame.height / 2)

        connectionDot.frame = NSRect(x: labelX - dotSize - 6, y: midY - dotSize / 2, width: dotSize, height: dotSize)

        let toggleX = connectionDot.frame.minX - iconSize - 4
        toggleButton.frame = NSRect(x: toggleX, y: midY - iconSize / 2, width: iconSize, height: iconSize)

        let autoX = toggleX - iconSize - 2
        autoReconnectButton.frame = NSRect(x: autoX, y: midY - iconSize / 2, width: iconSize, height: iconSize)
    }

    @objc private func toggleTapped() {
        onToggleConnection?()
    }

    @objc private func autoReconnectTapped() {
        onToggleAutoReconnect?()
    }
}
