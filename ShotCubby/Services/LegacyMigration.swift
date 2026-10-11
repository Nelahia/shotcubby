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

    /// Moves `~/ShotKeep` to `~/ShotCubby` wholesale, but only when the new
    /// vault doesn't exist yet — never merges into or overwrites one.
    private static func migrateVault() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let legacy = home.appendingPathComponent(legacyVaultName)
        let current = home.appendingPathComponent(vaultName)
        guard !FileManager.default.fileExists(atPath: current.path),
              FileManager.default.fileExists(atPath: legacy.path)
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
        let home = FileManager.default.homeDirectoryForCurrentUser
        let oldVaultPath = home.appendingPathComponent(legacyVaultName).path
        let newVaultPath = home.appendingPathComponent(vaultName).path
        for key in migratedKeys where defaults.object(forKey: key) == nil {
            guard var value = legacy[key] else { continue }
            if let path = value as? String, path.hasPrefix(oldVaultPath) {
                value = newVaultPath + path.dropFirst(oldVaultPath.count)
            }
            defaults.set(value, forKey: key)
        }
        // Dropped so the copy above can't resurrect a value the user has
        // since reset under the new identity.
        defaults.removePersistentDomain(forName: legacyDefaultsDomain)
    }
}
