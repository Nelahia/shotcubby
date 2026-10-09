import Foundation
import os

final class ScreenshotStorage {
    private let logger = Logger(subsystem: "com.nelahian.shotkeep", category: "ScreenshotStorage")

    let vaultURL: URL

    init() {
        vaultURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("ShotKeep")
    }

    func ensureVaultExists() {
        try? FileManager.default.createDirectory(
            at: vaultURL,
            withIntermediateDirectories: true
        )
    }

    /// Moves a capture into the vault. A plain rename is enough on a local
    /// folder, but a capture that lands inside a File Provider domain can
    /// still be owned by the provider's extension — the rename then fails,
    /// and silently dropping the capture would make file ingestion look
    /// like it "only works sometimes". Copying and trashing the original
    /// gets the file into the vault and lets the provider settle its own
    /// side.
    func moveToVault(_ sourceURL: URL) -> URL? {
        let destination = uniqueDestination(for: sourceURL)

        do {
            try FileManager.default.moveItem(at: sourceURL, to: destination)
            return destination
        } catch {
            let nsError = error as NSError
            logger.notice("""
            Move failed for \(sourceURL.lastPathComponent, privacy: .public) \
            (\(nsError.domain, privacy: .public) code \(nsError.code)); \
            falling back to copy
            """)
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            try? FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)
            return destination
        } catch {
            let nsError = error as NSError
            logger.error("""
            Copy also failed for \(sourceURL.lastPathComponent, privacy: .public): \
            \(nsError.domain, privacy: .public) code \(nsError.code) — \
            \(nsError.localizedDescription, privacy: .public)
            """)
            return nil
        }
    }

    func loadAll() -> [ScreenshotItem] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: vaultURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return files
            .filter { isImageFile($0) }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return lhsDate > rhsDate
            }
            .map { ScreenshotItem(url: $0) }
    }

    func delete(_ url: URL) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// Renames a screenshot already in the vault, keeping its extension.
    /// Returns the new URL, or `nil` if the name is empty or the move fails.
    func rename(_ url: URL, to newName: String) -> URL? {
        let sanitized = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return nil }
        guard sanitized != url.deletingPathExtension().lastPathComponent else { return url }

        let destination = uniqueDestination(baseName: sanitized, ext: url.pathExtension)
        do {
            try FileManager.default.moveItem(at: url, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    private func uniqueDestination(for sourceURL: URL) -> URL {
        uniqueDestination(
            baseName: sourceURL.deletingPathExtension().lastPathComponent,
            ext: sourceURL.pathExtension
        )
    }

    private func uniqueDestination(baseName: String, ext: String) -> URL {
        var destination = vaultURL.appendingPathComponent("\(baseName).\(ext)")
        var counter = 1

        while FileManager.default.fileExists(atPath: destination.path) {
            destination = vaultURL.appendingPathComponent("\(baseName)_\(counter).\(ext)")
            counter += 1
        }
        return destination
    }

    private func isImageFile(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "tiff", "heic"].contains(url.pathExtension.lowercased())
    }
}
