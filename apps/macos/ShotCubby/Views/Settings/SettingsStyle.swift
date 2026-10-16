import SwiftUI

/// Colors shared by the Settings components, matching the Windows settings.
enum SettingsStyle {
    static let accent = Color(red: 0.06, green: 0.71, blue: 0.79)
    static let warn = Color(red: 0.90, green: 0.62, blue: 0.22)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let fieldBackground = Color(nsColor: .textBackgroundColor)
    static let hairline = Color.primary.opacity(0.1)
}
