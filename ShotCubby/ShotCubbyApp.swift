import SwiftUI
import Carbon.HIToolbox

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
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var popover = NSPopover()
    private let appState = AppState()
    private var spotlight: SpotlightController?
    private var hotKey: GlobalHotKey?
    private var settingsWindow: NSWindow?
    /// Set only while the right-click menu is open, so it can be dismissed from elsewhere.
    private var contextMenu: NSMenu?
    /// Local key monitor that lets Esc close the status-item popover while it is shown.
    private var popoverKeyMonitor: Any?
    private var lastSpotlightToggle = Date.distantPast
    private let focus = FocusRestorer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Starts Sparkle (its scheduled checks) as early as the app itself.
        _ = AppUpdater.shared
        // Before anything reads the vault or the saved shortcut.
        LegacyMigration.run()
        DockPreferences.apply()
        setupMenuBar()
        setupPopover()
        setupSpotlight()
        appState.start()

        // Without this, the only thing that ever activates the app is the
        // user clicking the status item — and the global Spotlight hotkey
        // genuinely does not fire until that first activation happens, so
        // on a crowded menu bar (icon pushed off / hidden) the shortcut was
        // dead on arrival with no way to discover why. It needs no visible window.
        NSApp.activate(ignoringOtherApps: true)
        // Launching must not leave ShotCubby holding the keyboard with no window.
        focus.restoreIfStillActive()
    }

    /// Called when the user tries to open ShotCubby again while it's already
    /// running — double-clicking it in Finder/Applications, or launching it
    /// via Spotlight search — and it has no visible windows to bring
    /// forward — which is also what clicking the Dock icon does. ShotCubby has
    /// no window by design, so without this the click would do nothing. The Spotlight search panel is the
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
        popover.contentViewController = NSHostingController(
            rootView: PopoverHost(
                appState: appState,
                openSettings: { [weak self] in self?.showSettingsWindow() },
                openSpotlight: { [weak self] in self?.openSpotlightFromPopover() }
            )
        )
    }

    /// A transient popover closes on outside clicks but not on Esc, and the key
    /// press never reaches its SwiftUI content reliably, so watch for it here.
    /// A text field being edited (renaming a screenshot) keeps Esc for itself.
    func popoverDidShow(_ notification: Notification) {
        // Without being the key window the popover gets no key events at all —
        // Esc included — so the monitor below would never fire.
        popover.contentViewController?.view.window?.makeKey()
        popoverKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == UInt16(kVK_Escape) else { return event }
            if self.popover.contentViewController?.view.window?.firstResponder is NSText { return event }
            self.popover.performClose(nil)
            return nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let popoverKeyMonitor { NSEvent.removeMonitor(popoverKeyMonitor) }
        popoverKeyMonitor = nil
        focus.restoreIfStillActive()
    }

    /// Opening Spotlight from anywhere (shortcut, menu) must not leave the
    /// status-item popover or the right-click menu hanging open behind it.
    ///
    /// Closed without animation: an animated close finishes after Spotlight is
    /// already key, and AppKit then moves key status away from it, which made the
    /// panel close itself right after opening. Also ignores a second trigger a
    /// split second after the first (a double-delivered shortcut), which would
    /// toggle the panel straight back shut.
    private func toggleSpotlightDismissingMenus() {
        let now = Date()
        guard now.timeIntervalSince(lastSpotlightToggle) > 0.3 else { return }
        lastSpotlightToggle = now
        if popover.isShown { popover.close() }
        contextMenu?.cancelTracking()
        spotlight?.toggle()
    }

    private func openSpotlightFromPopover() {
        popover.close()
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
            window.delegate = self
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        guard let window = settingsWindow else { return }
        window.makeKeyAndOrderFront(nil)
        centerOnMouseScreen(window)
    }

    /// `NSWindow.center()` puts a window above the middle of the screen; the real
    /// middle of the screen the mouse is on is what is wanted.
    func windowWillClose(_ notification: Notification) {
        focus.restoreIfStillActive()
    }

    private func centerOnMouseScreen(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        window.layoutIfNeeded()
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
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
        spotlight?.onHide = { [weak self] in self?.focus.restoreIfStillActive() }
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

        let updatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdatesFromMenu),
            keyEquivalent: ""
        )
        updatesItem.target = self
        menu.addItem(updatesItem)

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

    @objc private func checkForUpdatesFromMenu() {
        AppUpdater.shared.checkForUpdates()
    }

    @objc private func openSettingsFromMenu() {
        showSettingsWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
