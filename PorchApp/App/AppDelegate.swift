import Cocoa
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var aboutWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let connectionManager = ConnectionManager.shared
    private let settings = PorchSettings.shared
    private let discovery = DeviceDiscovery.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()

        // Discover device, auto-grab API key, auto-connect, then start polling
        Task {
            if let config = await discovery.probe() {
                settings.applyFromDevice(config)
            }
            connectionManager.autoConnectIfEnabled()
            discovery.startPolling(interval: 30)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        discovery.stopPolling()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "house.circle", accessibilityDescription: "Porch")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                onSettings: { [weak self] in self?.showSettings() },
                onAbout: { [weak self] in self?.showAbout() },
                onQuit: { [weak self] in self?.quit() }
            )
            .environmentObject(connectionManager)
            .environmentObject(settings)
            .environmentObject(discovery)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showSettings() {
        popover.performClose(nil)

        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(settings: settings)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Porch Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 180))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                NSApp.setActivationPolicy(.accessory)
                self?.settingsWindow = nil
            }
        }
        settingsWindow = window
    }

    private func showAbout() {
        popover.performClose(nil)

        if let window = aboutWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = AboutView(settings: settings, discovery: discovery)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "About Porch"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 300, height: 230))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                NSApp.setActivationPolicy(.accessory)
                self?.aboutWindow = nil
            }
        }
        aboutWindow = window
    }

    private func quit() {
        connectionManager.disconnect()
        NSApp.terminate(nil)
    }
}
