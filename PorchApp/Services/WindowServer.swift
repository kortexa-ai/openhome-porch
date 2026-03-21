import Foundation
import Network

/// Local WebSocket server on port 9830 for the Window (Electrobun) app.
/// Porch sends JSON messages; Window renders them.
@MainActor
class WindowServer: ObservableObject {
    static let shared = WindowServer()

    @Published private(set) var isRunning = false
    @Published private(set) var windowConnected = false

    private var listener: NWListener?
    private var connection: NWConnection?
    private let port: UInt16 = 9830

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
        sendQuit()
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        isRunning = false
        windowConnected = false
        NSLog("[WindowServer] Stopped")
    }

    func send(_ message: [String: Any]) {
        guard let conn = connection else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let text = String(data: data, encoding: .utf8) else { return }

        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])

        conn.send(content: text.data(using: .utf8), contentContext: context, isComplete: true, completion: .idempotent)
    }

    func sendDisplay(_ text: String) {
        send(["type": "display", "data": text])
    }

    func sendQuit() {
        send(["type": "quit"])
    }

    // MARK: - Private

    private func handleNewConnection(_ conn: NWConnection) {
        // Only one Window client at a time
        connection?.cancel()
        connection = conn
        windowConnected = true
        NSLog("[WindowServer] Window connected")

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .failed = state, let self {
                    self.windowConnected = false
                    self.connection = nil
                    NSLog("[WindowServer] Window disconnected")
                }
            }
        }

        conn.start(queue: .global())
        receiveMessage(conn)
    }

    private func receiveMessage(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] data, context, _, error in
            Task { @MainActor in
                if let error {
                    NSLog("[WindowServer] Receive error: \(error)")
                    self?.windowConnected = false
                    self?.connection = nil
                    return
                }

                if let data, let text = String(data: data, encoding: .utf8) {
                    NSLog("[WindowServer] From Window: \(text)")
                }

                // Keep receiving
                if conn.state == .ready {
                    self?.receiveMessage(conn)
                }
            }
        }
    }
}
