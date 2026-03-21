import Foundation

enum ConnectionState {
    case disconnected
    case connecting
    case connected
}

/// Manages two WebSocket connections:
/// 1. Device socket (ws://openhome.local:3030) — config updates
/// 2. Cloud relay (ws://app.openhome.com:8769) — command execution for abilities
@MainActor
class ConnectionManager: ObservableObject {
    static let shared = ConnectionManager()

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var agentOnline = false

    /// Called whenever state changes
    var onStateChange: ((ConnectionState) -> Void)?

    private let settings = PorchSettings.shared
    private let discovery = DeviceDiscovery.shared
    private let backoffIntervals: [TimeInterval] = [10, 30, 60]
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var userDisconnected = false

    // Device socket (port 3030)
    private var deviceTask: URLSessionWebSocketTask?
    private var deviceSession: URLSession?
    private var deviceRetryTask: Task<Void, Never>?
    private var lastConfigText: String?

    // Cloud relay (port 8769)
    private var relayTask: URLSessionWebSocketTask?
    private var relaySession: URLSession?

    private init() {}

    func connect() {
        guard state == .disconnected else { return }
        guard settings.isConfigured else {
            NSLog("[Connection] No API key configured")
            return
        }

        userDisconnected = false
        reconnectAttempt = 0
        cancelReconnect()
        performConnect()
    }

    func disconnect() {
        userDisconnected = true
        cancelReconnect()
        closeAll()
        agentOnline = false
        setState(.disconnected)
        NSLog("[Connection] Disconnected (user)")
    }

    func autoConnectIfEnabled() {
        guard settings.autoReconnect, settings.isConfigured else { return }
        userDisconnected = false
        reconnectAttempt = 0
        connect()
    }

    // MARK: - Connect

    private func performConnect() {
        setState(.connecting)
        connectRelay(secure: false)

        // Also connect to device socket if discovered
        if let ip = discovery.deviceIP {
            connectDevice(host: ip)
        }
    }

    private func connectRelay(secure: Bool) {
        let scheme = secure ? "wss" : "ws"
        let relayURL = "\(scheme)://app.openhome.com:8769/?api_key=\(settings.apiKey)&client_id=porch&role=agent"
        guard let url = URL(string: relayURL) else {
            NSLog("[Connection] Bad relay URL")
            setState(.disconnected)
            return
        }

        NSLog("[Connection] Connecting to relay (\(scheme))...")
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        relaySession = URLSession(configuration: config)
        let task = relaySession!.webSocketTask(with: url)
        relayTask = task
        task.resume()
        receiveRelayMessage()

        // Timeout — if ws:// fails, try wss://
        Task {
            try? await Task.sleep(for: .seconds(5))
            if state == .connecting {
                if !secure {
                    NSLog("[Connection] ws:// timed out, trying wss://...")
                    relayTask?.cancel(with: .goingAway, reason: nil)
                    relayTask = nil
                    relaySession?.invalidateAndCancel()
                    relaySession = nil
                    connectRelay(secure: true)
                } else {
                    NSLog("[Connection] Relay handshake timeout")
                    closeAll()
                    setState(.disconnected)
                    scheduleReconnectIfNeeded()
                }
            }
        }
    }

    private func connectDevice(host: String) {
        guard let url = URL(string: "ws://\(host):3030/") else { return }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        deviceSession = URLSession(configuration: config)
        let task = deviceSession!.webSocketTask(with: url)
        deviceTask = task
        task.resume()
        receiveDeviceMessage()
    }

    private func setAgentOnline(_ online: Bool) {
        guard agentOnline != online else { return }
        agentOnline = online
        NSLog("[Device] Agent \(online ? "online" : "offline")")
    }

    // MARK: - Relay messages

    private func receiveRelayMessage() {
        relayTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    let text: String? = {
                        switch message {
                        case .string(let t): return t
                        case .data(let d): return String(data: d, encoding: .utf8)
                        @unknown default: return nil
                        }
                    }()
                    if let text { self.handleRelayMessage(text) }
                    self.receiveRelayMessage()

                case .failure(let error):
                    guard !self.userDisconnected else { return }
                    NSLog("[Relay] Lost: \(error.localizedDescription)")
                    self.relayTask = nil
                    self.closeAll()
                    self.setState(.disconnected)
                    self.scheduleReconnectIfNeeded()
                }
            }
        }
    }

    private func handleRelayMessage(_ text: String) {
        NSLog("[Relay] \(text)")

        // Mark as connected on first relay message
        if state != .connected {
            reconnectAttempt = 0
            setState(.connected)
            NSLog("[Connection] Connected to relay")
        }

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "welcome":
            // Already logged above
            break

        case "ping":
            sendToRelay(["type": "pong"])

        case "command", "relay":
            handleCommand(json)

        default:
            break
        }
    }

    private func handleCommand(_ json: [String: Any]) {
        let payload = json["data"]
        let command: String

        if let dict = payload as? [String: Any], let cmd = dict["cmd"] as? String {
            command = cmd
        } else if let str = payload as? String {
            command = str
        } else {
            NSLog("[Relay] Empty command payload, ignored")
            return
        }

        guard !command.isEmpty else { return }

        // Forward to Window if prefixed with "window:"
        if command.hasPrefix("window:") {
            let jsonStr = String(command.dropFirst("window:".count))
            NSLog("[Relay] → Window: \(jsonStr)")
            if let data = jsonStr.data(using: .utf8),
               let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                WindowServer.shared.send(msg)
            } else {
                // Plain text display
                WindowServer.shared.sendDisplay(jsonStr)
            }
            sendToRelay(["type": "response", "data": ["ok": true, "stdout": "forwarded to window"]])
            return
        }

        NSLog("[Relay] Executing: \(command)")

        // Run command in background
        Task.detached {
            let result = Self.runCommand(command)
            await MainActor.run {
                NSLog("[Relay] Result: ok=\(result["ok"] as? Bool ?? false)")
                self.sendToRelay(["type": "response", "data": result])
            }
        }
    }

    private nonisolated static func runCommand(_ command: String) -> [String: Any] {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = ProcessInfo.processInfo.environment

        do {
            try process.run()
            process.waitUntilExit()

            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()

            return [
                "ok": process.terminationStatus == 0,
                "returncode": Int(process.terminationStatus),
                "stdout": String(data: outData, encoding: .utf8) ?? "",
                "stderr": String(data: errData, encoding: .utf8) ?? "",
            ]
        } catch {
            return ["ok": false, "error": error.localizedDescription]
        }
    }

    private func sendToRelay(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        relayTask?.send(.string(text)) { error in
            if let error {
                NSLog("[Relay] Send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Device messages

    private func receiveDeviceMessage() {
        deviceTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    let text: String? = {
                        switch message {
                        case .string(let t): return t
                        case .data(let d): return String(data: d, encoding: .utf8)
                        @unknown default: return nil
                        }
                    }()
                    if let text { self.handleDeviceMessage(text) }
                    self.receiveDeviceMessage()

                case .failure(let error):
                    guard !self.userDisconnected else { return }
                    NSLog("[Device] Lost: \(error.localizedDescription)")
                    self.deviceTask = nil
                    self.deviceSession?.invalidateAndCancel()
                    self.deviceSession = nil
                    self.setAgentOnline(false)
                    self.scheduleDeviceRetry()
                }
            }
        }
    }

    private func handleDeviceMessage(_ text: String) {
        setAgentOnline(true)
        if let data = text.data(using: .utf8),
           let cfg = try? JSONDecoder().decode(DeviceConfig.self, from: data) {
            if text != lastConfigText {
                NSLog("[Device] \(text)")
                lastConfigText = text
            }
            discovery.updateConfig(cfg)
        } else {
            NSLog("[Device] \(text)")
        }
    }

    /// Retry device socket every 30s until it connects or user disconnects
    private func scheduleDeviceRetry() {
        deviceRetryTask?.cancel()
        deviceRetryTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, !userDisconnected else { return }
            guard deviceTask == nil else { return }
            let ip: String?
            if let cached = discovery.deviceIP {
                ip = cached
            } else {
                ip = await resolveDevice()
            }
            if let ip {
                NSLog("[Device] Retrying \(ip):3030...")
                connectDevice(host: ip)
            } else {
                scheduleDeviceRetry()
            }
        }
    }

    private func resolveDevice() async -> String? {
        await discovery.resolveDevice()
        return discovery.deviceIP
    }

    // MARK: - Reconnect

    private func scheduleReconnectIfNeeded() {
        guard settings.autoReconnect else { return }
        guard !userDisconnected else { return }
        guard reconnectAttempt < backoffIntervals.count else {
            NSLog("[Connection] Auto-reconnect exhausted after \(backoffIntervals.count) attempts")
            return
        }

        let delay = backoffIntervals[reconnectAttempt]
        reconnectAttempt += 1
        NSLog("[Connection] Reconnect \(reconnectAttempt)/\(backoffIntervals.count) in \(Int(delay))s")

        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            guard state == .disconnected, !userDisconnected else { return }
            performConnect()
        }
    }

    private func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    private func closeAll() {
        relayTask?.cancel(with: .goingAway, reason: nil)
        relayTask = nil
        relaySession?.invalidateAndCancel()
        relaySession = nil
        deviceTask?.cancel(with: .goingAway, reason: nil)
        deviceTask = nil
        deviceSession?.invalidateAndCancel()
        deviceSession = nil
        deviceRetryTask?.cancel()
        deviceRetryTask = nil
        lastConfigText = nil
    }

    private func setState(_ newState: ConnectionState) {
        state = newState
        onStateChange?(newState)
    }
}
