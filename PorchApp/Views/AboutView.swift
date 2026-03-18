import SwiftUI

struct AboutView: View {
    @ObservedObject var settings: PorchSettings
    @ObservedObject var discovery: DeviceDiscovery

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "house.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.primary)

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
        .frame(width: 300, height: 230)
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
}
