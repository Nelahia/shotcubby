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
    private var archiveTimer: Timer?

    /// Published so Settings follows a move.
    @Published private(set) var vaultURL = ScreenshotStorage.currentVaultURL
    var screenshotDirectory: String { watcher.screenshotDir.path }

    func start() {
        storage.ensureVaultExists()
        loadExistingScreenshots()
        observeNewScreenshots()
        observeClipboard()
        observeDayArchive()
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
        panel.prompt = tr("Use This Folder")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        FolderPreferences.setCustomDirectory(url)
        accessFailure = nil
        watcher.restart()
    }

    /// Asks where, confirms, then moves the whole vault there.
    func moveVault() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = tr("Choose where ShotCubby keeps your screenshots")
        panel.prompt = tr("Choose")
        guard panel.runModal() == .OK, let chosen = panel.url else { return }

        let target = ScreenshotStorage.target(forChosen: chosen)
        let alert = NSAlert()
        alert.messageText = String(format: tr("Move your screenshots to “%@”?"), chosen.lastPathComponent)
        let summary = String(
            format: tr("%@, dated folders included, will move to the new location. New captures will be saved there."),
            ScreenshotStorage.summaryText(screenshots)
        )
        let from = (vaultURL.path as NSString).abbreviatingWithTildeInPath
        let to = (target.path as NSString).abbreviatingWithTildeInPath
        alert.informativeText = "\(summary)\n\n\(tr("From")): \(from)\n\(tr("To")): \(to)"
        alert.addButton(withTitle: tr("Move"))
        alert.addButton(withTitle: tr("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        DispatchQueue.global(qos: .userInitiated).async { [storage] in
            let result = Result { try storage.moveVault(to: target) }
            DispatchQueue.main.async { [weak self] in self?.finishVaultMove(result) }
        }
    }

    private func finishVaultMove(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            vaultURL = storage.vaultURL
            screenshots = storage.loadAll()
        case .failure(let error):
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = tr("Can't move")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
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

    /// Files past days into dated folders when the option is on: at launch,
    /// when it is switched on, and every few minutes so a day that ends while
    /// the app is open is picked up soon after midnight.
    private func observeDayArchive() {
        NotificationCenter.default.publisher(for: OrganizePreferences.didChange)
            .sink { [weak self] _ in self?.archivePastDays() }
            .store(in: &cancellables)
        archiveTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.archivePastDays()
        }
        archivePastDays()
    }

    private func archivePastDays() {
        guard OrganizePreferences.organizeByDay else { return }
        DispatchQueue.global(qos: .utility).async { [storage] in
            guard storage.archivePastDays() else { return }
            // Re-read on the main thread so a capture that arrived meanwhile
            // is never dropped from the list.
            DispatchQueue.main.async { [weak self] in
                self?.screenshots = storage.loadAll()
            }
        }
    }

    private func loadExistingScreenshots() {
        screenshots = storage.loadAll()
    }

    private func observeClipboard() {
        clipboardWatcher.onNewClipboardImage = { [weak self] url in
            let item = ScreenshotItem(url: url)
            DispatchQueue.main.async {
                self?.screenshots.insert(item, at: 0)
                self?.nameWithAI(item)
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
                self.nameWithAI(item)
            }
        }
        watcher.startWatching()
    }
}
