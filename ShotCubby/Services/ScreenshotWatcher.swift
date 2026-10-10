import Foundation
import os

/// Why the screenshot folder cannot be read. The card needs more than a Bool:
/// a plain Desktop denial and a denial on a cloud-synced folder are granted in
/// two different panes of System Settings, and sending the user to the wrong
/// one is what made the permission card look unclearable.
enum FolderAccessFailure: Equatable {
    /// The folder lives inside a third-party File Provider domain
    /// (~/Library/CloudStorage/<Provider>-<Account>), e.g. a Desktop that
    /// OneDrive redirected. Granted under Privacy & Security > Files and
    /// Folders, and only when NSFileProviderDomainUsageDescription ships in
    /// the bundle — without it macOS denies and never prompts.
    case cloudProvider(name: String)

    /// A plain TCC-protected folder: Desktop, Documents, Downloads.
    case protectedFolder

    /// The folder is gone: a custom folder was deleted, a volume unmounted.
    case missing
}

final class ScreenshotWatcher {
    private let logger = Logger(subsystem: "com.nelahian.shotcubby", category: "ScreenshotWatcher")

    var onNewScreenshot: ((URL) -> Void)?
    var onAccessFailed: ((FolderAccessFailure) -> Void)?

    /// Everything that touches `knownFiles` runs here. A single kqueue callback
    /// used to own that set; the polling fallback below can now fire at the
    /// same time, and two threads mutating one Set is a crash, not a missed
    /// screenshot.
    private let queue = DispatchQueue(label: "com.nelahian.shotcubby.watcher")

    private var source: DispatchSourceFileSystemObject?
    private var pollTimer: DispatchSourceTimer?
    private var knownFiles = Set<String>()
    private var pendingSizes: [String: Int] = [:]

    private(set) var screenshotDir: URL

    init() {
        screenshotDir = Self.resolveScreenshotDirectory()
    }

    // MARK: - Lifecycle

    func startWatching() {
        stopWatching()
        if let failure = accessFailure() {
            onAccessFailed?(failure)
            return
        }
        snapshotCurrentFiles()
        watchDirectory()
        startPollingFallback()
    }

    /// Re-resolves the screenshot directory (picks up a newly chosen custom
    /// folder) and restarts watching from scratch.
    func restart() {
        stopWatching()
        screenshotDir = Self.resolveScreenshotDirectory()
        startWatching()
    }

    func stopWatching() {
        source?.cancel()
        source = nil
        pollTimer?.cancel()
        pollTimer = nil
    }

    // MARK: - Access

    /// `nil` when the folder can be listed. Mapping the error to a case rather
    /// than returning a Bool is what lets the card name the pane that actually
    /// holds the grant.
    private func accessFailure() -> FolderAccessFailure? {
        do {
            _ = try FileManager.default.contentsOfDirectory(
                at: screenshotDir,
                includingPropertiesForKeys: nil
            )
            logger.notice("Access OK for \(self.screenshotDir.path, privacy: .public)")
            return nil
        } catch {
            let nsError = error as NSError
            logger.error("""
            Access denied for \(self.screenshotDir.path, privacy: .public): \
            \(nsError.domain, privacy: .public) code \(nsError.code) — \
            \(nsError.localizedDescription, privacy: .public)
            """)

            if !FileManager.default.fileExists(atPath: screenshotDir.path) {
                return .missing
            }
            if let provider = Self.cloudProviderName(for: screenshotDir) {
                return .cloudProvider(name: provider)
            }
            return .protectedFolder
        }
    }

    /// The provider's display name when `url` sits inside a File Provider
    /// domain, `nil` otherwise. Those domains are laid out as
    /// ~/Library/CloudStorage/<Provider>-<Account>/…, and TCC guards them with
    /// a service of their own — not the Desktop one, even when the folder *is*
    /// the Desktop by way of a symlink. That mismatch is the whole bug.
    static func cloudProviderName(for url: URL) -> String? {
        let cloudRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/CloudStorage")
            .standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(cloudRoot + "/") else { return nil }

        guard let domain = path
            .dropFirst(cloudRoot.count + 1)
            .split(separator: "/")
            .first
        else { return nil }

        // "OneDrive-BOUYGUESTELECOM" -> "OneDrive"
        // "GoogleDrive-someone@gmail.com" -> "GoogleDrive"
        return String(domain.split(separator: "-").first ?? domain)
    }

    // MARK: - Watching

    private func snapshotCurrentFiles() {
        let names = (try? FileManager.default.contentsOfDirectory(
            at: screenshotDir,
            includingPropertiesForKeys: nil
        ))?.map(\.lastPathComponent) ?? []
        queue.sync { knownFiles = Set(names) }
    }

    private func watchDirectory() {
        let fd = open(screenshotDir.path, O_EVTONLY)
        guard fd >= 0 else {
            logger.error("""
            open() failed for \(self.screenshotDir.path, privacy: .public): \
            errno \(errno)
            """)
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )
        source.setEventHandler { [weak self] in self?.checkForNewScreenshots() }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    /// kqueue fires on a write to the directory's vnode. Inside a File Provider
    /// domain the provider's extension can materialize a file without that
    /// write ever reaching the descriptor we hold, so a capture can land
    /// unnoticed. A ten-second sweep costs nothing and closes that hole.
    private func startPollingFallback() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 10, repeating: 10)
        timer.setEventHandler { [weak self] in self?.checkForNewScreenshots() }
        timer.resume()
        pollTimer = timer
    }

    /// Always runs on `queue`.
    private func checkForNewScreenshots() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: screenshotDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }

        for file in files where !knownFiles.contains(file.lastPathComponent) {
            knownFiles.insert(file.lastPathComponent)
            guard isScreenshotFile(file) else { continue }
            announceWhenStable(file)
        }
    }

    /// A capture is announced only once its size stops changing. screencapture
    /// writes the PNG in place, and a provider-backed folder can surface a
    /// zero-byte placeholder first — moving either one truncates the capture.
    /// Always runs on `queue`.
    private func announceWhenStable(_ url: URL, attempt: Int = 0) {
        let maxAttempts = 20        // 20 × 0.5 s = 10 s, then give up
        let size = fileSize(of: url)

        if size > 0, pendingSizes[url.path] == size {
            pendingSizes[url.path] = nil
            let handler = onNewScreenshot
            DispatchQueue.main.async { handler?(url) }
            return
        }

        guard attempt < maxAttempts else {
            pendingSizes[url.path] = nil
            logger.error("""
            Never settled, skipping: \(url.lastPathComponent, privacy: .public)
            """)
            return
        }

        pendingSizes[url.path] = size
        queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.announceWhenStable(url, attempt: attempt + 1)
        }
    }

    private func fileSize(of url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    }

    // MARK: - Matching

    private func isScreenshotFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "tiff"].contains(ext) else { return false }

        // macOS names French captures with a typographic apostrophe (U+2019),
        // not the ASCII one, so normalize before matching. The accent needs no
        // normalizing: Swift compares by canonical equivalence, which already
        // matches the decomposed form APFS stores.
        let name = url.lastPathComponent
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")

        return name.contains("screenshot")
            || name.contains("capture d'écran")
            || name.contains("capture d'ecran")
    }

    // MARK: - Location

    /// Resolves to the *real* directory, following symlinks. ~/Desktop is often
    /// a symlink into ~/Library/CloudStorage when OneDrive or iCloud redirects
    /// it; macOS enforces TCC on the resolved target, not on the link. Watching
    /// the unresolved path means asking the user for a Desktop grant that macOS
    /// never consults, which leaves the permission card up forever.
    private static func resolveScreenshotDirectory() -> URL {
        rawScreenshotDirectory().resolvingSymlinksInPath()
    }

    private static func rawScreenshotDirectory() -> URL {
        if let customDirectory = FolderPreferences.customDirectory {
            return customDirectory
        }
        if let customPath = UserDefaults(suiteName: "com.apple.screencapture")?
            .string(forKey: "location") {
            return URL(fileURLWithPath: (customPath as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
    }
}
