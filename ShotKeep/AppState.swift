import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published private(set) var screenshots: [ScreenshotItem] = []
    /// `nil` once the folder is readable. Holding the reason rather than a
    /// Bool is what lets the card name the right pane of System Settings.
    @Published private(set) var accessFailure: FolderAccessFailure?

    private let storage = ScreenshotStorage()
    private let watcher = ScreenshotWatcher()
    private lazy var clipboardWatcher = ClipboardWatcher(storage: storage)
    private var cancellables = Set<AnyCancellable>()

    var vaultURL: URL { storage.vaultURL }
    var screenshotDirectory: String { watcher.screenshotDir.path }

    func start() {
        storage.ensureVaultExists()
        loadExistingScreenshots()
        observeNewScreenshots()
        observeClipboard()
    }

    /// Opens the pane that actually holds the grant. A folder inside a File
    /// Provider domain is allowed under Files and Folders; Full Disk Access
    /// covers it too, but that is a far bigger ask for a menu bar app, and
    /// pointing there was why users kept flipping a switch that changed
    /// nothing.
    func openPrivacySettings() {
        let anchor: String
        switch accessFailure {
        case .cloudProvider:
            anchor = "Privacy_FilesAndFolders"
        default:
            anchor = "Privacy_AllFiles"
        }
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
        )
    }

    /// macOS caches a TCC denial for the lifetime of the process, which is
    /// why System Settings offers "Quit & Reopen" whenever a switch is
    /// flipped. Re-testing in-process cannot get past that cache, so the
    /// card offers a real relaunch instead of a retry that could never
    /// succeed.
    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    /// Called every time the popover opens: a grant made in System Settings
    /// while the app was running is noticed only if we look again.
    func retryScreenshotAccess() {
        guard accessFailure != nil else { return }
        accessFailure = nil
        watcher.startWatching()
    }

    func chooseCustomFolder() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use This Folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        FolderPreferences.setCustomDirectory(url)
        accessFailure = nil
        watcher.restart()
    }

    func deleteScreenshot(_ item: ScreenshotItem) {
        storage.delete(item.url)
        screenshots.removeAll { $0.id == item.id }
    }

    func renameScreenshot(_ item: ScreenshotItem, to newName: String) {
        // The clipboard/file distinction is read back from the filename
        // (see ScreenshotItem.source), so a clipboard capture keeps its tag
        // through a rename even though the user never sees it.
        var sanitized = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if item.source == .clipboard, !sanitized.hasSuffix("(clipboard)") {
            sanitized += " (clipboard)"
        }

        guard let newURL = storage.rename(item.url, to: sanitized) else { return }
        guard let index = screenshots.firstIndex(where: { $0.id == item.id }) else { return }
        screenshots[index] = ScreenshotItem(url: newURL)
    }

    func revealInFinder(_ item: ScreenshotItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func openScreenshot(_ item: ScreenshotItem) {
        NSWorkspace.shared.open(item.url)
    }

    func copyToClipboard(_ item: ScreenshotItem) {
        guard let image = NSImage(contentsOf: item.url) else { return }
        clipboardWatcher.pauseTemporarily()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    func openVaultFolder() {
        NSWorkspace.shared.open(vaultURL)
    }

    private func loadExistingScreenshots() {
        screenshots = storage.loadAll()
    }

    private func observeClipboard() {
        clipboardWatcher.onNewClipboardImage = { [weak self] url in
            let item = ScreenshotItem(url: url)
            DispatchQueue.main.async {
                self?.screenshots.insert(item, at: 0)
            }
        }
        clipboardWatcher.startWatching()
    }

    private func observeNewScreenshots() {
        watcher.onAccessFailed = { [weak self] failure in
            DispatchQueue.main.async {
                self?.accessFailure = failure
            }
        }
        watcher.onNewScreenshot = { [weak self] url in
            guard let self else { return }
            guard let movedURL = self.storage.moveToVault(url) else { return }
            let item = ScreenshotItem(url: movedURL)
            DispatchQueue.main.async {
                self.screenshots.insert(item, at: 0)
            }
        }
        watcher.startWatching()
    }
}
