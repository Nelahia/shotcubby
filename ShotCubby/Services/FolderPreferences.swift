import Foundation

enum FolderPreferences {
    private static let key = "customScreenshotDirectoryPath"

    static var customDirectory: URL? {
        guard let path = UserDefaults.standard.string(forKey: key) else { return nil }
        return URL(fileURLWithPath: path)
    }

    static func setCustomDirectory(_ url: URL?) {
        if let url {
            UserDefaults.standard.set(url.path, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
