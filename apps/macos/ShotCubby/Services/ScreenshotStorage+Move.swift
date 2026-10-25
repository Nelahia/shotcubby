import Foundation

/// Moving the whole vault to another place, from Settings.
extension ScreenshotStorage {
    enum MoveError: LocalizedError {
        case sameFolder, nested, notEmpty, failed

        var errorDescription: String? {
            switch self {
            case .sameFolder: tr("That is already the current folder.")
            case .nested: tr("Choose a folder outside the current one.")
            case .notEmpty: tr("That folder isn't empty.")
            case .failed: tr("Couldn't move the screenshots there. Nothing was lost.")
            }
        }
    }

    /// The vault path for a folder the user picked: the folder itself when it
    /// is already called `ShotCubby`, else a `ShotCubby` folder inside it, so
    /// the app never mixes with other files.
    static func target(forChosen chosen: URL) -> URL {
        chosen.lastPathComponent == "ShotCubby" ? chosen : chosen.appendingPathComponent("ShotCubby")
    }

    /// "128 screenshots · 412 MB".
    static func summaryText(_ items: [ScreenshotItem]) -> String {
        let bytes = items.reduce(Int64(0)) { total, item in
            total + Int64((try? item.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return "\(String(format: tr(items.count == 1 ? "%lld screenshot" : "%lld screenshots"), items.count)) · \(size)"
    }

    /// Moves the vault to `target` and remembers it. Across volumes the file
    /// manager copies then removes, so nothing is deleted before it is safe.
    func moveVault(to target: URL) throws {
        let source = vaultURL.standardizedFileURL.path
        let destination = target.standardizedFileURL.path
        guard destination != source else { throw MoveError.sameFolder }
        guard !destination.hasPrefix(source + "/"), !source.hasPrefix(destination + "/")
        else { throw MoveError.nested }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: destination, isDirectory: &isDirectory),
           !isDirectory.boolValue || !contents(of: target).isEmpty {
            throw MoveError.notEmpty
        }

        do {
            try fileManager.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: source) {
                try? fileManager.removeItem(at: target)   // only an empty folder gets here
                try fileManager.moveItem(at: vaultURL, to: target)
            } else {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
            }
        } catch {
            throw MoveError.failed
        }
        VaultPreferences.set(destination == Self.defaultVaultURL.standardizedFileURL.path ? nil : target)
    }
}
