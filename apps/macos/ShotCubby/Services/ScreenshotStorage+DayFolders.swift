import Foundation

/// Filing past days' screenshots into `YYYY-MM-DD` folders (see
/// `OrganizePreferences`). Today's stay at the vault's root until the day is
/// over, so they remain where they have always been.
extension ScreenshotStorage {
    /// Moves every screenshot taken before today from the vault's root into a
    /// folder named after its day. Returns whether anything moved.
    @discardableResult
    func archivePastDays() -> Bool {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        var moved = false

        for file in contents(of: vaultURL) where isImageFile(file) {
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            guard let created, created < startOfToday else { continue }

            let folder = vaultURL.appendingPathComponent(Self.dayFormatter.string(from: created))
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let destination = uniqueDestination(
                    baseName: file.deletingPathExtension().lastPathComponent,
                    ext: file.pathExtension,
                    in: folder
                )
                try FileManager.default.moveItem(at: file, to: destination)
                moved = true
            } catch {
                continue
            }
        }
        return moved
    }

    /// The `YYYY-MM-DD` folders in the vault, and only those: any other
    /// folder the user keeps there is left alone.
    func dayFolders() -> [URL] {
        contents(of: vaultURL).filter { url in
            let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            guard isFolder, let date = Self.dayFormatter.date(from: url.lastPathComponent) else { return false }
            return Self.dayFormatter.string(from: date) == url.lastPathComponent
        }
    }

    func contents(of directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        )) ?? []
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
