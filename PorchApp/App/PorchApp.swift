import SwiftUI

@main
struct PorchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — app lives entirely in the menu bar
        Settings {
            EmptyView()
        }
    }
}
