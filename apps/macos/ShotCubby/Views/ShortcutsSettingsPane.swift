import SwiftUI

struct ShortcutsSettingsPane: View {
    @State private var keyCode: UInt32 = HotKeyPreferences.keyCode
    @State private var modifiers: UInt32 = HotKeyPreferences.modifiers

    var body: some View {
        SettingsPage(
            title: "Shortcuts",
            subtitle: "Click a combination, then press the keys you want. Global shortcuts need a modifier (⌘ ⌥ ⌃ ⇧). Esc cancels."
        ) {
            SettingsCard {
                SettingsRow(title: "Open Spotlight search", subtitle: "Works from anywhere.") {
                    HotKeyRecorderField(keyCode: $keyCode, modifiers: $modifiers)
                    Button("Reset") {
                        keyCode = HotKeyPreferences.defaultKeyCode
                        modifiers = HotKeyPreferences.defaultModifiers
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            Text("Inside the search panel").font(.headline).padding(.top, 4)
            Text("Return and the function keys can be used alone; every other shortcut needs a modifier.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, -10)

            SettingsCard {
                ForEach(Array(SpotlightCommand.allCases.enumerated()), id: \.element.id) { index, command in
                    if index > 0 { Divider() }
                    SpotlightShortcutRow(command: command)
                }
            }
        }
        .onChange(of: keyCode) { _, _ in save() }
        .onChange(of: modifiers) { _, _ in save() }
    }

    private func save() {
        HotKeyPreferences.set(keyCode: keyCode, modifiers: modifiers)
    }
}
