import SwiftUI

@main
struct ShotKeepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover = NSPopover()
    private let appState = AppState()
    private var spotlight: SpotlightController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupPopover()
        setupSpotlight()
        appState.start()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(named: "MenuBarGlyph")
        button.image?.isTemplate = true
        button.image?.accessibilityDescription = "ShotKeep"
        button.action = #selector(handleStatusItemClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverHost(appState: appState)
        )
    }

    private func setupSpotlight() {
        spotlight = SpotlightController(
            shots: { [weak self] in self?.appState.screenshots.map(ShotBridge.toShot) ?? [] },
            actions: ShotBridge.actions(for: appState)
        )
        registerHotKey()
        NotificationCenter.default.addObserver(
            forName: HotKeyPreferences.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerHotKey()
        }
    }

    private func registerHotKey() {
        hotKey = GlobalHotKey(
            keyCode: HotKeyPreferences.keyCode,
            modifiers: HotKeyPreferences.modifiers
        ) { [weak self] in
            self?.spotlight?.toggle()
        }
    }

    @objc private func handleStatusItemClick() {
        guard let button = statusItem?.button, let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu(relativeTo: button)
        } else {
            togglePopover(relativeTo: button)
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton) {
        let menu = NSMenu()

        let searchItem = NSMenuItem(
            title: "Search\u{2026}",
            action: #selector(toggleSpotlight),
            keyEquivalent: ""
        )
        searchItem.target = self
        menu.addItem(searchItem)

        let openFolderItem = NSMenuItem(
            title: "Open Folder",
            action: #selector(openFolderFromMenu),
            keyEquivalent: ""
        )
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit ShotKeep",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func toggleSpotlight() {
        spotlight?.toggle()
    }

    @objc private func openFolderFromMenu() {
        appState.openVaultFolder()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
