import Foundation

/// Manages launching and stopping the Window (Electrobun) process.
@MainActor
class WindowLauncher: ObservableObject {
    static let shared = WindowLauncher()

    @Published private(set) var isRunning = false

    private var process: Process?
    private let server = WindowServer.shared

    private init() {}

    func launch() {
        guard !isRunning else { return }

        // Start the WebSocket server first
        server.start()

        // Find the Window directory relative to the Porch binary
        let windowDir = findWindowDir()
        guard let dir = windowDir else {
            NSLog("[WindowLauncher] Could not find Window directory")
            return
        }

        NSLog("[WindowLauncher] Launching from \(dir)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/Users/francip/.bun/bin/bun")
        proc.arguments = ["start"]
        proc.currentDirectoryURL = URL(fileURLWithPath: dir)
        proc.environment = ProcessInfo.processInfo.environment

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                NSLog("[WindowLauncher] Window process exited")
                self?.isRunning = false
                self?.process = nil
                self?.server.stop()
            }
        }

        do {
            try proc.run()
            process = proc
            isRunning = true
        } catch {
            NSLog("[WindowLauncher] Failed to launch: \(error)")
            server.stop()
        }
    }

    func stop() {
        server.sendQuit()

        // Give it a moment to close gracefully, then force kill
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if self?.process?.isRunning == true {
                self?.process?.terminate()
            }
            self?.process = nil
            self?.isRunning = false
            self?.server.stop()
        }
    }

    private func findWindowDir() -> String? {
        let candidates = [
            // Running from source (swift run)
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Window").path,
            // Relative to binary
            URL(fileURLWithPath: Bundle.main.executablePath ?? "")
                .deletingLastPathComponent()
                .appendingPathComponent("Window").path,
            // Hardcoded dev path
            "/Users/francip/src/openhome-porch/Window",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0 + "/package.json") }
    }
}
