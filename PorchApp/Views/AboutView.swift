import SwiftUI

struct AboutView: View {
    @ObservedObject var settings: PorchSettings
    @ObservedObject var discovery: DeviceDiscovery

    var body: some View {
        VStack(spacing: 12) {
            if let icon = loadIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 4)
            } else {
                Image(systemName: "house.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.primary)
            }

            Text("Porch")
                .font(.title.bold())

            Text("A macOS client for your OpenHome device")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("by kortexa.ai")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer().frame(height: 4)

            // Device discovery status
            HStack(spacing: 6) {
                Circle()
                    .fill(discovery.isDiscovered ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                if let ip = discovery.deviceIP {
                    Text("OpenHome discovered: \(ip)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No OpenHome device found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // API key status
            HStack(spacing: 6) {
                Circle()
                    .fill(settings.isConfigured ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(apiKeyStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 300, height: 260)
    }

    private var apiKeyStatusText: String {
        guard settings.isConfigured else {
            return "API key not configured"
        }
        switch settings.apiKeySource {
        case .device:
            return "API key (from device)"
        case .saved:
            return "API key configured"
        case .none:
            return "API key configured"
        }
    }

    private func loadIcon() -> NSImage? {
        let candidates = [
            Bundle.main.bundlePath + "/Contents/Resources/appIcon.png",
            URL(fileURLWithPath: Bundle.main.executablePath ?? "")
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("assets/appIcon.png").path,
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("assets/appIcon.png").path,
        ]
        for path in candidates {
            if let img = NSImage(contentsOfFile: path) { return img }
        }
        return nil
    }
}
