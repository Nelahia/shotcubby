import AppKit

enum Appearance: String, CaseIterable, Identifiable {
    case light, dark

    var id: String { rawValue }
    var title: String { self == .light ? "Light" : "Dark" }
}

/// Light unless the user switched to dark in Settings. Set on the whole app,
/// so the popover, the search panel and Settings all follow it.
enum AppearancePreferences {
    private static let key = "appearance"

    static var current: Appearance {
        UserDefaults.standard.string(forKey: key).flatMap(Appearance.init(rawValue:)) ?? .light
    }

    @MainActor
    static func set(_ appearance: Appearance) {
        UserDefaults.standard.set(appearance.rawValue, forKey: key)
        apply()
    }

    @MainActor
    static func apply() {
        NSApp.appearance = NSAppearance(named: current == .dark ? .darkAqua : .aqua)
    }
}
