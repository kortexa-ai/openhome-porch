import SwiftUI

struct DeviceInfoView: View {
    let config: DeviceConfig
    let deviceIP: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenHome Device")
                .font(.title2.bold())

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                row("IP Address", deviceIP)
                row("MAC Address", config.macAddress)
                row("Cloud", config.wsURL)
                row("Personality", config.defaultPersonality)
                row("Volume", "\(config.speakerVolume)%")
                row("Mic Sensitivity", "\(config.micSensitivity)%")
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 100, alignment: .trailing)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}
