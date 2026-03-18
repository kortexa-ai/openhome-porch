import Foundation

/// Discovers an OpenHome device on the local network via DNS resolution.
/// Config is received through the persistent WebSocket connection in ConnectionManager.
@MainActor
class DeviceDiscovery: ObservableObject {
    static let shared = DeviceDiscovery()

    @Published private(set) var deviceIP: String? = nil
    @Published private(set) var config: DeviceConfig? = nil

    var isDiscovered: Bool { deviceIP != nil }

    private var pollTask: Task<Void, Never>?

    private init() {}

    /// Called by ConnectionManager when it receives a config update
    func updateConfig(_ cfg: DeviceConfig) {
        config = cfg
    }

    /// Start periodic DNS checks (only useful when disconnected, to detect device appearing)
    func startPolling(interval: TimeInterval = 30) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                // Skip if already connected — we know the device is there
                if ConnectionManager.shared.state != .connected {
                    await resolveDevice()
                }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Resolve openhome.local and optionally fetch config (only when not connected)
    @discardableResult
    func probe() async -> DeviceConfig? {
        await resolveDevice()

        guard let ip = deviceIP else { return nil }

        // Fetch config via throwaway connection (only needed for initial setup before persistent connection)
        if ConnectionManager.shared.state != .connected {
            if let cfg = await fetchConfig(host: ip, port: 3030) {
                config = cfg
                return cfg
            }
        }
        return config
    }

    func resolveDevice() async {
        guard let ip = await resolveHost("openhome.local") else {
            deviceIP = nil
            return
        }
        deviceIP = ip
    }

    private func resolveHost(_ hostname: String) async -> String? {
        await Task.detached {
            var hints = addrinfo()
            hints.ai_family = AF_INET
            hints.ai_socktype = SOCK_STREAM

            var result: UnsafeMutablePointer<addrinfo>?
            let status = getaddrinfo(hostname, nil, &hints, &result)
            defer { if result != nil { freeaddrinfo(result) } }

            guard status == 0, let info = result else { return nil }

            let addr = info.pointee.ai_addr!
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                var ip = sin.pointee.sin_addr
                inet_ntop(AF_INET, &ip, &buffer, socklen_t(INET_ADDRSTRLEN))
            }
            return String(cString: buffer)
        }.value
    }

    private func fetchConfig(host: String, port: UInt16) async -> DeviceConfig? {
        var ws: DeviceWebSocket? = nil
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<DeviceConfig?, Never>) in
            let socket = DeviceWebSocket(host: host, port: port)
            ws = socket
            socket.connect { config in
                continuation.resume(returning: config)
            }
        }
        _ = ws
        return result
    }
}

/// Minimal WebSocket client to read the first message from port 3030.
/// Only used for initial config fetch before the persistent connection is established.
private class DeviceWebSocket: NSObject, URLSessionWebSocketDelegate {
    private let host: String
    private let port: UInt16
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var completion: ((DeviceConfig?) -> Void)?

    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    func connect(completion: @escaping (DeviceConfig?) -> Void) {
        self.completion = completion
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        guard let url = URL(string: "ws://\(host):\(port)/") else {
            completion(nil)
            return
        }

        task = session?.webSocketTask(with: url)
        task?.resume()

        task?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let cfg = try? JSONDecoder().decode(DeviceConfig.self, from: data) {
                        self?.finish(cfg)
                    } else {
                        self?.finish(nil)
                    }
                default:
                    self?.finish(nil)
                }
            case .failure:
                self?.finish(nil)
            }
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.finish(nil)
        }
    }

    private func finish(_ config: DeviceConfig?) {
        guard let completion = completion else { return }
        self.completion = nil
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        completion(config)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {}
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {}
}
