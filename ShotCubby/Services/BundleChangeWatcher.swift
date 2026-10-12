import AppKit

/// Relaunches ShotCubby by itself after the app has been replaced on disk by a
/// newer version (dragging a new copy over it in Applications). The old
/// process keeps running from the file it already loaded, so without this the
/// new version only takes over once the old one is killed and started again.
@MainActor
final class BundleChangeWatcher {
    private static let interval: TimeInterval = 5
    /// Gives a copy in progress time to finish before the new app is launched.
    private static let settleDelay = 2

    private let runningVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    private let infoPlistURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Info.plist")
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    private func check() {
        // Read from disk each time: `Bundle` caches the version it loaded at launch.
        guard let plist = NSDictionary(contentsOf: infoPlistURL),
              let diskVersion = plist["CFBundleShortVersionString"] as? String,
              diskVersion != runningVersion
        else { return }

        timer?.invalidate()
        relaunch()
    }

    /// The new copy is started only after this one has quit: both would
    /// otherwise register the same global shortcut, and the newcomer would lose it.
    private func relaunch() {
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", "sleep \(Self.settleDelay); /usr/bin/open \"$0\"", Bundle.main.bundleURL.path]
        try? helper.run()
        NSApp.terminate(nil)
    }
}
