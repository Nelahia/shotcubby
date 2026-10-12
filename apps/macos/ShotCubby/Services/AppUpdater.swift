import Sparkle

/// macOS in-app updates, through Sparkle: it reads the appcast published with
/// each release, shows its own "update available" window, then downloads,
/// verifies (against the public key in Info.plist), installs and relaunches.
/// Nothing is installed until the user accepts in that window.
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    /// Whether Sparkle looks for updates by itself (about once a day).
    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            controller.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
