import SwiftUI

@main
struct ShotCubbyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var popover = NSPopover()
    private let appState = AppState()
    private var spotlight: SpotlightController?
    private var hotKey: GlobalHotKey?
    private var settingsWindow: NSWindow?
    /// Set only while the right-click menu is open, so it can be dismissed from elsewhere.
    private var contextMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Before anything reads the vault or the saved shortcut.
        LegacyMigration.run()
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

    /// Called when the user tries to open ShotCubby again while it's already
    /// running — double-clicking it in Finder/Applications, or launching it
    /// via Spotlight search — and it has no visible windows to bring
    /// forward. An .accessory app has none by design, so without this the
    /// click would silently do nothing. The Spotlight search panel is the
    /// closest thing ShotCubby has to a main window, so that's what opens.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        spotlight?.show()
        return true
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(named: "MenuBarGlyph")
        button.image?.isTemplate = true
        button.image?.accessibilityDescription = "ShotCubby"
        button.action = #selector(handleStatusItemClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let controller = PopoverHostingController(
            rootView: PopoverHost(
                appState: appState,
                openSettings: { [weak self] in self?.showSettingsWindow() },
                openSpotlight: { [weak self] in self?.openSpotlightFromPopover() }
            )
        )
        controller.onCancel = { [weak self] in self?.popover.performClose(nil) }
        popover.contentViewController = controller
    }

    /// Makes the popover's content the first responder so Esc reaches it —
    /// otherwise the key press goes to the window and nothing closes.
    func popoverDidShow(_ notification: Notification) {
        guard let controller = popover.contentViewController else { return }
        controller.view.window?.makeFirstResponder(controller.view)
    }

    /// Opening Spotlight from anywhere (shortcut, menu) must not leave the
    /// status-item popover or the right-click menu hanging open behind it.
    private func toggleSpotlightDismissingMenus() {
        if popover.isShown { popover.performClose(nil) }
        contextMenu?.cancelTracking()
        spotlight?.toggle()
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
            window.title = "ShotCubby Settings"
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
        // Release (and unregister) the old one before creating the new one,
        // rather than letting the assignment below do it implicitly: Swift
        // evaluates the right-hand side first, which would otherwise keep
        // the old GlobalHotKey alive — and its Carbon handler installed —
        // for the whole time the new one is being registered.
        hotKey = nil
        hotKey = GlobalHotKey(
            keyCode: HotKeyPreferences.keyCode,
            modifiers: HotKeyPreferences.modifiers
        ) { [weak self] in
            self?.toggleSpotlightDismissingMenus()
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
            title: "Quit ShotCubby",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        contextMenu = menu
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        contextMenu = nil
    }

    @objc private func toggleSpotlight() {
        toggleSpotlightDismissingMenus()
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
