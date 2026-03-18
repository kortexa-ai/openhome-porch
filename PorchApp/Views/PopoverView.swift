import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var settings: PorchSettings
    @EnvironmentObject var discovery: DeviceDiscovery

    @State private var showDeviceInfo = false

    var onSettings: () -> Void
    var onAbout: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()

            // Status row
            statusRow
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Expandable device info
            if showDeviceInfo, let config = discovery.config, let ip = discovery.deviceIP {
                Divider()
                    .padding(.horizontal, 12)
                deviceInfoSection(config: config, ip: ip)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            Divider()

            // Footer
            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Porch")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "gear")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 8) {
            // Device/agent status dot: green = agent online, orange = device found but agent off, red = no device
            Circle()
                .fill(connectionManager.agentOnline ? Color.green : (discovery.isDiscovered ? Color.orange : Color.red))
                .frame(width: 8, height: 8)

            // Device IP / label (clickable to expand)
            Button(action: {
                if discovery.config != nil {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showDeviceInfo.toggle()
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Text(discovery.deviceIP ?? "No device")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                    if discovery.config != nil {
                        Image(systemName: showDeviceInfo ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if discovery.config != nil {
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }

            Spacer()

            // Auto-reconnect toggle
            IconToggle(
                icon: "arrow.clockwise",
                isOn: settings.autoReconnect,
                onColor: .blue,
                offColor: .gray.opacity(0.4),
                tooltip: settings.autoReconnect ? "Auto-reconnect: On" : "Auto-reconnect: Off"
            ) {
                settings.autoReconnect.toggle()
                settings.save()
            }

            // Connect / disconnect button
            IconToggle(
                icon: connectionManager.state == .disconnected ? "play.fill" : "stop.fill",
                isOn: true,
                onColor: connectionManager.state == .disconnected ? .green : .red,
                offColor: .gray,
                tooltip: connectionManager.state == .disconnected ? "Connect" : "Disconnect",
                enabled: settings.isConfigured && connectionManager.state != .connecting
            ) {
                if connectionManager.state == .connected {
                    connectionManager.disconnect()
                } else {
                    connectionManager.connect()
                }
            }

            // Connection status bolt (indicator, not a button)
            Image(systemName: "bolt.fill")
                .font(.system(size: 12))
                .foregroundColor(connectionManager.state == .connected ? .yellow : .gray.opacity(0.4))
        }
    }

    // MARK: - Device Info

    private func deviceInfoSection(config: DeviceConfig, ip: String) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            infoRow("MAC", config.macAddress)
            infoRow("Cloud", config.wsURL)
            infoRow("Personality", config.defaultPersonality)
            infoRow("Volume", "\(config.speakerVolume)%")
            infoRow("Mic", "\(config.micSensitivity)%")
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(minWidth: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("About", action: onAbout)
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            Text("·")
                .foregroundStyle(.tertiary)
            Button("Quit", action: onQuit)
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
        }
    }
}

// MARK: - Icon Toggle Button

struct IconToggle: View {
    let icon: String
    let isOn: Bool
    let onColor: Color
    let offColor: Color
    var tooltip: String = ""
    var enabled: Bool = true
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isOn ? onColor : offColor)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hovering ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .help(tooltip)
        .onHover { h in
            hovering = h
            if enabled {
                if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
    }
}
