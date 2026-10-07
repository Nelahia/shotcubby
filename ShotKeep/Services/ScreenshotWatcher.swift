import Foundation

final class ScreenshotWatcher {
    var onNewScreenshot: ((URL) -> Void)?
    var onPermissionDenied: (() -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var knownFiles = Set<String>()
    let screenshotDir: URL

    init() {
        screenshotDir = ScreenshotWatcher.resolveScreenshotDirectory()
    }

    func startWatching() {
        guard verifyAccess() else {
            onPermissionDenied?()
            return
        }
        snapshotCurrentFiles()
        watchDirectory()
    }

    private func verifyAccess() -> Bool {
        do {
            _ = try FileManager.default.contentsOfDirectory(
                at: screenshotDir,
                includingPropertiesForKeys: nil
            )
            return true
        } catch {
            return false
        }
    }

    func stopWatching() {
        source?.cancel()
        source = nil
    }

    private func snapshotCurrentFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: screenshotDir,
            includingPropertiesForKeys: nil
        ) else { return }
        knownFiles = Set(files.map(\.lastPathComponent))
    }

    private func watchDirectory() {
        let fd = open(screenshotDir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .global(qos: .utility)
        )

        source?.setEventHandler { [weak self] in
            self?.checkForNewScreenshots()
        }

        source?.setCancelHandler { close(fd) }
        source?.resume()
    }

    private func checkForNewScreenshots() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: screenshotDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let newFiles = files.filter { !knownFiles.contains($0.lastPathComponent) }

        for file in newFiles {
            knownFiles.insert(file.lastPathComponent)
            guard isScreenshotFile(file) else { continue }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.onNewScreenshot?(file)
            }
        }
    }

    private func isScreenshotFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "tiff"].contains(ext) else { return false }
        return name.contains("screenshot") || name.contains("capture d'écran")
            || name.contains("capture d'ecran")
    }

    private static func resolveScreenshotDirectory() -> URL {
        if let customPath = UserDefaults(suiteName: "com.apple.screencapture")?
            .string(forKey: "location") {
            return URL(fileURLWithPath: (customPath as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }
}
