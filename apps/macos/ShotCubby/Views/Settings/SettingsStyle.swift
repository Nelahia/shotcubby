import SwiftUI

/// Colors shared by the Settings components, the navy palette, matching the
/// Windows settings. Each one follows the Light / Dark choice in Settings.
enum SettingsStyle {
    static let window = Color.adaptive(light: 0xDCE3EF, dark: 0x111522)
    static let surface = Color.adaptive(light: 0xF3F6FB, dark: 0x1E263B)
    static let raised = Color.adaptive(light: 0xC7D1E3, dark: 0x303D59)
    static let ink = Color.adaptive(light: 0x111522, dark: 0xDCE3EF)
    static let muted = Color.adaptive(light: 0x536684, dark: 0x98A9C4)
    static let accent = Color.adaptive(light: 0x303D59, dark: 0x98A9C4)
    static let onAccent = Color.adaptive(light: 0xDCE3EF, dark: 0x111522)
    static let switchOn = Color.adaptive(light: 0x303D59, dark: 0x536684)
    static let warn = Color.adaptive(light: 0xA85A00, dark: 0xF2B25C)
    static let hairline = Color.adaptive(light: 0x111522, dark: 0x98A9C4, lightAlpha: 0.14, darkAlpha: 0.18)
    static let cardBackground = surface
    static let fieldBackground = window
}
