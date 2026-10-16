import SwiftUI

/// One key of a shortcut, drawn as a small keycap.
struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .padding(.horizontal, 7)
            .frame(minWidth: 26, minHeight: 26)
            .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(SettingsStyle.hairline)
            )
    }
}

enum KeyCaps {
    private static let modifiers: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]

    /// Splits a described shortcut ("⌘⇧S") into its keys: each modifier on
    /// its own, then the rest as the last key.
    static func parts(of combo: String) -> [String] {
        var parts: [String] = []
        var key = ""
        for character in combo {
            if key.isEmpty, character == " " { continue }
            if key.isEmpty, modifiers.contains(character) {
                parts.append(String(character))
            } else {
                key.append(character)
            }
        }
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { parts.append(trimmed) }
        return parts
    }
}
