import Foundation

/// Configuration received from the OpenHome device's local WebSocket (port 3030).
struct DeviceConfig: Codable {
    let apiKey: String
    let wsURL: String
    let apiURL: String
    let defaultPersonality: String
    let macAddress: String
    let speakerVolume: String
    let micSensitivity: String

    enum CodingKeys: String, CodingKey {
        case apiKey = "API_KEY"
        case wsURL = "WS_URL"
        case apiURL = "API_URL"
        case defaultPersonality = "DEFAULT_PERSONALITY"
        case macAddress = "MAC_ADDRESS"
        case speakerVolume = "SPEAKER_VOLUME"
        case micSensitivity = "MIC_SENSITIVITY"
    }
}
