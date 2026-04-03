import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: PorchSettings
    @State private var editingKey: String = ""
    @State private var launchAtLogin: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("OpenHome API Key")
                    .font(.subheadline.bold())

                SecureField("Paste your API key", text: $editingKey)
                    .textFieldStyle(.roundedBorder)

                Text("Get your key from app.openhome.com → Settings → API Keys")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .font(.subheadline)
                .onChange(of: launchAtLogin) { _, newValue in
                    settings.launchAtLogin = newValue
                    settings.save()
                    if newValue {
                        LaunchDManager.shared.install()
                    } else {
                        LaunchDManager.shared.uninstall()
                    }
                }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    settings.apiKey = editingKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    settings.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editingKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400, height: 230)
        .onAppear {
            editingKey = settings.apiKey
            launchAtLogin = settings.launchAtLogin
        }
    }
}
