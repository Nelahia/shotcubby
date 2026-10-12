import Foundation

/// Whether past days' screenshots are filed into `YYYY-MM-DD` folders. On
/// unless the user switched it off in Settings.
enum OrganizePreferences {
    private static let key = "organizeByDay"

    static let didChange = Notification.Name("OrganizePreferencesDidChange")

    static var organizeByDay: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    static func set(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: key)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
