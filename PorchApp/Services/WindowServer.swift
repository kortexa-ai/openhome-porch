import Foundation
import Network

/// Local WebSocket server on port 9830 for Window's bun process.
/// Single connection — bun process forwards messages to webview via RPC.
@MainActor
class WindowServer: ObservableObject {
    static let shared = WindowServer()

    @Published private(set) var isRunning = false
    @Published private(set) var windowConnected = false

    private var listener: NWListener?
    private var connection: NWConnection?
    private let port: UInt16 = 9830

    /// Last display message — replayed when Window connects
    private var pendingMessage: [String: Any]?

    private init() {}

    func start() {
        guard !isRunning else { return }

        do {
            let params = NWParameters.tcp
            let wsOptions = NWProtocolWebSocket.Options()
            params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        NSLog("[WindowServer] Listening on port \(self?.port ?? 0)")
                        self?.isRunning = true
                    case .failed(let error):
                        NSLog("[WindowServer] Failed: \(error)")
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            listener?.newConnectionHandler = { [weak self] conn in
                Task { @MainActor in
                    self?.handleNewConnection(conn)
                }
            }
            listener?.start(queue: .global())
        } catch {
            NSLog("[WindowServer] Error starting: \(error)")
        }
    }

    func stop() {
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        isRunning = false
        windowConnected = false
        pendingMessage = nil
        NSLog("[WindowServer] Stopped")
    }

    func send(_ message: [String: Any]) {
        let msgType = message["type"] as? String

        // Buffer display messages
        if msgType == "render" || msgType == "render-3d" || msgType == "display" || msgType == "now-playing" {
            pendingMessage = message
        } else if msgType == "clear" {
            pendingMessage = nil
        }

        guard let conn = connection else {
            if pendingMessage != nil {
                NSLog("[WindowServer] Buffered message (Window not connected yet)")
            }
            return
        }
        sendRaw(message, on: conn)
    }

    func sendDisplay(_ text: String) {
        send(["type": "display", "data": text])
    }

    func sendQuit() {
        pendingMessage = nil
        guard let conn = connection else { return }
        sendRaw(["type": "quit"], on: conn)
    }

    // MARK: - Private

    private func sendRaw(_ message: [String: Any], on conn: NWConnection) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let text = String(data: data, encoding: .utf8) else { return }

        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        conn.send(content: text.data(using: .utf8), contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func handleNewConnection(_ conn: NWConnection) {
        // Replace existing connection (bun reconnect)
        if connection != nil {
            connection?.cancel()
            connection = nil
        }
        connection = conn
        windowConnected = true
        NSLog("[WindowServer] Window connected")

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .failed, .cancelled:
                    // Only log if this is still the active connection
                    if self?.connection === conn {
                        self?.windowConnected = false
                        self?.connection = nil
                        NSLog("[WindowServer] Window disconnected")
                    }
                default:
                    break
                }
            }
        }

        conn.start(queue: .global())
        receiveMessage(conn)

        // Replay buffered message
        if let pending = pendingMessage {
            NSLog("[WindowServer] Replaying buffered message")
            sendRaw(pending, on: conn)
        }
    }

    private func receiveMessage(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] data, context, _, error in
            Task { @MainActor in
                if let error {
                    if self?.connection === conn {
                        NSLog("[WindowServer] Receive error: \(error)")
                        self?.windowConnected = false
                        self?.connection = nil
                    }
                    return
                }

                if let data, let text = String(data: data, encoding: .utf8) {
                    NSLog("[WindowServer] From Window: \(text)")
                }

                if conn.state == .ready {
                    self?.receiveMessage(conn)
                }
            }
        }
    }
}
