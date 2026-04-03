import Foundation

/// Manages launching and stopping the Window (Electrobun) app.
/// Supports two modes:
/// - **Prod**: Window.app is embedded in Porch.app/Contents/Resources/ — launches the native launcher
/// - **Dev**: Window/ source dir found on disk — runs `bun start` to build and launch
@MainActor
class WindowLauncher: ObservableObject {
    static let shared = WindowLauncher()

    @Published private(set) var isRunning = false

    private var process: Process?
    private let server = WindowServer.shared

    private init() {}

    func launch() {
        guard !isRunning else { return }

        server.start()

        // Try prod mode first (embedded Window.app), then dev mode
        if let appPath = findEmbeddedWindowApp() {
            launchProd(appPath: appPath)
        } else if let srcDir = findWindowSourceDir() {
            launchDev(sourceDir: srcDir)
        } else {
            NSLog("[WindowLauncher] Could not find Window (neither embedded app nor source dir)")
            server.stop()
        }
    }

    func stop() {
        if server.windowConnected {
            server.sendQuit()
        } else {
            process?.terminate()
        }
        // terminationHandler will clean up
    }

    // MARK: - Prod mode (embedded Window.app)

    private func findEmbeddedWindowApp() -> String? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let candidates = [
            resourceURL.appendingPathComponent("Window.app").path,
            resourceURL.appendingPathComponent("Window-canary.app").path,
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0 + "/Contents/MacOS/launcher") }
    }

    private func launchProd(appPath: String) {
        NSLog("[WindowLauncher] Launching (prod): \(appPath)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: appPath + "/Contents/MacOS/launcher")
        proc.environment = ProcessInfo.processInfo.environment
        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                NSLog("[WindowLauncher] Window exited")
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

    // MARK: - Dev mode (source directory + bun)

    private func findWindowSourceDir() -> String? {
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Window").path,
            URL(fileURLWithPath: Bundle.main.executablePath ?? "")
                .deletingLastPathComponent()
                .appendingPathComponent("Window").path,
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0 + "/package.json") }
    }

    private func findBun() -> String? {
        // Try which bun first
        let which = Process()
        let pipe = Pipe()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["bun"]
        which.standardOutput = pipe
        which.standardError = FileHandle.nullDevice
        try? which.run()
        which.waitUntilExit()
        if which.terminationStatus == 0 {
            let path = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let path, !path.isEmpty { return path }
        }

        // Fallback paths
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fallbacks = [
            "\(home)/.bun/bin/bun",
            "/opt/homebrew/bin/bun",
            "/usr/local/bin/bun",
        ]
        return fallbacks.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func launchDev(sourceDir: String) {
        guard let bunPath = findBun() else {
            NSLog("[WindowLauncher] Could not find bun")
            server.stop()
            return
        }

        NSLog("[WindowLauncher] Launching (dev): \(sourceDir) with \(bunPath)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bunPath)
        proc.arguments = ["start"]
        proc.currentDirectoryURL = URL(fileURLWithPath: sourceDir)
        proc.environment = ProcessInfo.processInfo.environment
        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                NSLog("[WindowLauncher] Window exited")
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
}
