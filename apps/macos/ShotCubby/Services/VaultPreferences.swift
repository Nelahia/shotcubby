import Foundation

/// Where the user moved the vault, when they did. Absent means the default
/// (`~/Documents/ShotCubby`).
enum VaultPreferences {
    private static let key = "vaultDirectoryPath"

    static var customURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: key) else { return nil }
        return URL(fileURLWithPath: path)
    }

    static func set(_ url: URL?) {
        if let url {
            UserDefaults.standard.set(url.path, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
