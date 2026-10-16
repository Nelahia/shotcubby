import Foundation

/// The sidebar entries of the Settings window.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general, screenshots, aiNaming, shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .screenshots: "Screenshots"
        case .aiNaming: "AI naming"
        case .shortcuts: "Shortcuts"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .screenshots: "folder"
        case .aiNaming: "sparkles"
        case .shortcuts: "keyboard"
        }
    }
}
