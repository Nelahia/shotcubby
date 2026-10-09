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
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupPopover()
        setupSpotlight()
        appState.start()

        // Without this, the only thing that ever activates the app is the
        // user clicking the status item — and the global Spotlight hotkey
        // genuinely does not fire until that first activation happens, so
        // on a crowded menu bar (icon pushed off / hidden) the shortcut was
        // dead on arrival with no way to discover why. .accessory apps can
        // still activate; this only keeps them out of the Dock and ⌘-Tab,
        // it does not require any visible window.
        NSApp.activate(ignoringOtherApps: true)
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
            rootView: PopoverHost(
                appState: appState,
                openSettings: { [weak self] in self?.showSettingsWindow() },
                openSpotlight: { [weak self] in self?.openSpotlightFromPopover() }
            )
        )
    }

    private func openSpotlightFromPopover() {
        popover.performClose(nil)
        spotlight?.show()
    }

    /// Owned directly rather than via `NSApp.sendAction(Selector(("showSettingsWindow:")))`:
    /// that responder-chain action targets SwiftUI's auto-generated Settings command, which
    /// is wired through the app's main menu — an `.accessory` app (no Dock icon, no menu bar)
    /// never gets one, so the action silently finds no responder and does nothing.
    private func showSettingsWindow() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "ShotKeep Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func setupSpotlight() {
        spotlight = SpotlightController(
            shots: { [weak self] in self?.appState.screenshots.map(ShotBridge.toShot) ?? [] },
            actions: ShotBridge.actions(
                for: appState,
                openSettings: { [weak self] in self?.showSettingsWindow() },
                openSpotlight: { [weak self] in self?.spotlight?.toggle() }
            )
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
            // Re-check here rather than in the SwiftUI view: the popover's
            // hosting controller is built once and reused, so onAppear fires
            // only on the first show and a grant made later is never noticed.
            appState.retryScreenshotAccess()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton) {
        let menu = NSMenu()

        let shortcut = HotKeyPreferences.menuKeyEquivalent(keyCode: HotKeyPreferences.keyCode, modifiers: HotKeyPreferences.modifiers)
        let searchItem = NSMenuItem(
            title: "Search\u{2026}",
            action: #selector(toggleSpotlight),
            keyEquivalent: shortcut.key
        )
        searchItem.keyEquivalentModifierMask = shortcut.mask
        searchItem.target = self
        menu.addItem(searchItem)

        let openFolderItem = NSMenuItem(
            title: "Open Folder",
            action: #selector(openFolderFromMenu),
            keyEquivalent: ""
        )
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        let settingsItem = NSMenuItem(
            title: "Settings\u{2026}",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

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

    @objc private func openSettingsFromMenu() {
        showSettingsWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
