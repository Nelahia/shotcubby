import Foundation

/// One-shot move of everything the app was called ShotKeep (bundle
/// `com.nelahian.shotkeep`) left on a Mac, so an update to ShotCubby
/// feels like the same app: same captures, same shortcut, same folder.
/// Run once at launch, before anything reads the vault or the preferences.
enum LegacyMigration {
    private static let legacyDefaultsDomain = "com.nelahian.shotkeep"
    private static let legacyVaultName = "ShotKeep"
    private static let vaultName = "ShotCubby"
    private static let migratedKeys = [
        "customScreenshotDirectoryPath",
        "spotlightHotKeyCode",
        "spotlightHotKeyModifiers"
    ]

    static func run() {
        migrateVault()
        migrateDefaults()
    }

    /// Where the vault lived before: `~/ShotCubby`, and `~/ShotKeep` before
    /// that. Newest first.
    private static var legacyVaults: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [vaultName, legacyVaultName].map { home.appendingPathComponent($0) }
    }

    /// Moves the old vault to `~/Documents/ShotCubby` wholesale, but only
    /// when the new vault doesn't exist yet — never merges into or
    /// overwrites one.
    private static func migrateVault() {
        let current = ScreenshotStorage.defaultVaultURL
        guard !FileManager.default.fileExists(atPath: current.path),
              let legacy = legacyVaults.first(where: { FileManager.default.fileExists(atPath: $0.path) })
        else { return }
        try? FileManager.default.moveItem(at: legacy, to: current)
    }

    /// Copies the settings the user chose, skipping any already set under
    /// the new identity. A custom screenshot folder inside the old vault
    /// is rewritten to the moved location.
    private static func migrateDefaults() {
        guard let legacy = UserDefaults.standard.persistentDomain(forName: legacyDefaultsDomain)
        else { return }
        let defaults = UserDefaults.standard
        let oldVaultPaths = legacyVaults.map(\.path)
        let newVaultPath = ScreenshotStorage.defaultVaultURL.path
        for key in migratedKeys where defaults.object(forKey: key) == nil {
            guard var value = legacy[key] else { continue }
            if let path = value as? String,
               let oldVaultPath = oldVaultPaths.first(where: { path.hasPrefix($0) }) {
                value = newVaultPath + path.dropFirst(oldVaultPath.count)
            }
            defaults.set(value, forKey: key)
        }
        // Dropped so the copy above can't resurrect a value the user has
        // since reset under the new identity.
        defaults.removePersistentDomain(forName: legacyDefaultsDomain)
    }
}
