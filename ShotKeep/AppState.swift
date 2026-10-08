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

    func deleteScreenshot(_ item: ScreenshotItem) {
        storage.delete(item.url)
        screenshots.removeAll { $0.id == item.id }
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
