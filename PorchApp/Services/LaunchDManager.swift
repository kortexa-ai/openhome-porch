import Foundation

/// Manages the launchd service for Porch — install/uninstall at login.
/// Generates the plist dynamically using the current app bundle path.
@MainActor
class LaunchDManager {
    static let shared = LaunchDManager()

    private let label = "ai.kortexa.porch"
    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    private init() {}

    func install() {
        let execPath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]
        let logPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/porch.log").path

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(execPath)</string>
            </array>
            <key>KeepAlive</key>
            <true/>
            <key>RunAtLoad</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(logPath)</string>
            <key>StandardErrorPath</key>
            <string>\(logPath)</string>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
            </dict>
        </dict>
        </plist>
        """

        do {
            // Ensure LaunchAgents dir exists
            let dir = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
            NSLog("[LaunchD] Plist written to \(plistURL.path)")

            // Load the service
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            proc.arguments = ["load", plistURL.path]
            try proc.run()
            proc.waitUntilExit()
            NSLog("[LaunchD] Service loaded (exit: \(proc.terminationStatus))")
        } catch {
            NSLog("[LaunchD] Install failed: \(error)")
        }
    }

    func uninstall() {
        // Unload first
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["unload", plistURL.path]
        try? proc.run()
        proc.waitUntilExit()

        // Remove plist
        try? FileManager.default.removeItem(at: plistURL)
        NSLog("[LaunchD] Service uninstalled")
    }
}
