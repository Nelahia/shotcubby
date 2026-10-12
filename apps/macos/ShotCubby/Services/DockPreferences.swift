import AppKit

/// Whether ShotCubby also shows in the Dock. On by default: clicking the
/// Dock icon opens the search panel (see `applicationShouldHandleReopen`).
/// Off keeps it a pure menu bar app, as before.
enum DockPreferences {
    private static let key = "showInDock"

    static var showInDock: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    @MainActor
    static func set(_ show: Bool) {
        UserDefaults.standard.set(show, forKey: key)
        apply()
    }

    @MainActor
    static func apply() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        // Changing the policy can drop the app from the foreground.
        if showInDock { NSApp.activate(ignoringOtherApps: true) }
    }
}
