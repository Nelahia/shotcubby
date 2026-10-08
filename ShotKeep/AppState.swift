import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published private(set) var screenshots: [ScreenshotItem] = []
    @Published var permissionDenied = false

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

    func openPrivacySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        )
    }

    func retryScreenshotAccess() {
        guard permissionDenied else { return }
        permissionDenied = false
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
        permissionDenied = false
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
        watcher.onPermissionDenied = { [weak self] in
            DispatchQueue.main.async {
                self?.permissionDenied = true
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
