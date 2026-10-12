import AppKit

/// Gives the keyboard back to the app the user was working in when ShotCubby
/// holds the focus but has nothing to show for it — its popover or Settings
/// window just closed. Otherwise no window is key, and ⌘V, ⌘C… go nowhere
/// until the user clicks back into their own app.
@MainActor
final class FocusRestorer {
    private var lastOtherApp: NSRunningApplication?
    private var observer: NSObjectProtocol?

    init() {
        lastOtherApp = NSWorkspace.shared.frontmostApplication.flatMap(Self.other)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let other = Self.other(app)
            else { return }
            MainActor.assumeIsolated { self?.lastOtherApp = other }
        }
    }

    deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    private nonisolated static func other(_ app: NSRunningApplication) -> NSRunningApplication? {
        app.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : app
    }

    /// Checked a beat later, once the closing window has really gone: if
    /// ShotCubby is still the active app with no key window, hand the focus back.
    /// Clicking into another app has already deactivated it, so nothing is stolen.
    func restoreIfStillActive() {
        DispatchQueue.main.async { [weak self] in
            guard NSApp.isActive, NSApp.keyWindow == nil,
                  let app = self?.lastOtherApp, !app.isTerminated
            else { return }
            NSApp.yieldActivation(to: app)
            app.activate()
        }
    }
}
