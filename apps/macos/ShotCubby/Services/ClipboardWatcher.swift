import AppKit
import Combine

final class ClipboardWatcher {
    var onNewClipboardImage: ((URL) -> Void)?

    private var timer: Timer?
    private var lastChangeCount: Int
    private var isPaused = false
    private let storage: ScreenshotStorage

    init(storage: ScreenshotStorage) {
        self.storage = storage
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func pauseTemporarily() {
        isPaused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.lastChangeCount = NSPasteboard.general.changeCount
            self?.isPaused = false
        }
    }

    func startWatching() {
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.8,
            repeats: true
        ) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        guard !isPaused else { return }
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard hasImageContent(pasteboard) else { return }
        guard let image = NSImage(pasteboard: pasteboard) else { return }
        guard let savedURL = saveClipboardImage(image) else { return }

        onNewClipboardImage?(savedURL)
    }

    private func hasImageContent(_ pasteboard: NSPasteboard) -> Bool {
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        return pasteboard.availableType(from: imageTypes) != nil
    }

    private func saveClipboardImage(_ image: NSImage) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else { return nil }

        let timestamp = DateFormatter.screenshotFormatter.string(from: Date())
        // Two copies within one second must not share a file: the second would
        // overwrite the first and leave two list entries for a single path. The
        // counter goes before the tag, which has to stay the end of the name.
        var destination = storage.vaultURL.appendingPathComponent("Screenshot \(timestamp) (clipboard).png")
        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = storage.vaultURL.appendingPathComponent("Screenshot \(timestamp)_\(counter) (clipboard).png")
            counter += 1
        }

        do {
            try pngData.write(to: destination)
            return destination
        } catch {
            return nil
        }
    }
}

private extension DateFormatter {
    static let screenshotFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter
    }()
}
