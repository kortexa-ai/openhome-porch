import Foundation

/// Persistent settings stored in ~/.config/porch/settings.json
@MainActor
class PorchSettings: ObservableObject {
    static let shared = PorchSettings()

    @Published var apiKey: String = ""
    @Published var autoReconnect: Bool = false
    @Published var launchAtLogin: Bool = false

    /// Where the API key came from
    @Published private(set) var apiKeySource: ApiKeySource = .none

    var isConfigured: Bool { !apiKey.isEmpty }

    private let configDir: URL
    private let configFile: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/porch")
        configFile = configDir.appendingPathComponent("settings.json")
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: configFile.path) else { return }
        do {
            let data = try Data(contentsOf: configFile)
            let json = try JSONDecoder().decode(SettingsFile.self, from: data)
            apiKey = json.apiKey ?? ""
            autoReconnect = json.autoReconnect ?? false
            launchAtLogin = json.launchAtLogin ?? false
            if !apiKey.isEmpty {
                apiKeySource = .saved
            }
        } catch {
            print("[Settings] Failed to load: \(error)")
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let json = SettingsFile(apiKey: apiKey.isEmpty ? nil : apiKey, autoReconnect: autoReconnect, launchAtLogin: launchAtLogin)
            let data = try JSONEncoder().encode(json)
            try data.write(to: configFile, options: .atomic)
            if !apiKey.isEmpty {
                apiKeySource = .saved
            }
        } catch {
            print("[Settings] Failed to save: \(error)")
        }
    }

    /// Auto-configure from a discovered device, only if not already configured
    func applyFromDevice(_ config: DeviceConfig) {
        print("[Settings] applyFromDevice called, isConfigured=\(isConfigured), key=\(config.apiKey.prefix(8))...")
        guard !isConfigured else { return }
        apiKey = config.apiKey
        apiKeySource = .device
        save()
        print("[Settings] API key saved from device")
    }

    enum ApiKeySource {
        case none
        case saved      // from settings.json (manual or previously auto-saved)
        case device     // auto-grabbed from device this session
    }
}

private struct SettingsFile: Codable {
    var apiKey: String?
    var autoReconnect: Bool?
    var launchAtLogin: Bool?
}
