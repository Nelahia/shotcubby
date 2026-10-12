import SwiftUI

struct ShortcutsSettingsPane: View {
    @State private var keyCode: UInt32 = HotKeyPreferences.keyCode
    @State private var modifiers: UInt32 = HotKeyPreferences.modifiers

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Open Spotlight search")
                    Spacer()
                    HotKeyRecorderField(keyCode: $keyCode, modifiers: $modifiers)
                    Button("Reset") {
                        keyCode = HotKeyPreferences.defaultKeyCode
                        modifiers = HotKeyPreferences.defaultModifiers
                    }
                }
            } header: {
                Text("Global shortcut")
            } footer: {
                Text("Click the field, then press a key combination with at least one modifier (⌘ ⌥ ⌃ ⇧). Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(SpotlightCommand.allCases) { command in
                    SpotlightShortcutRow(command: command)
                }
            } header: {
                Text("Inside the search panel")
            } footer: {
                Text("Return and the function keys can be used alone; every other shortcut needs a modifier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: keyCode) { _, _ in save() }
        .onChange(of: modifiers) { _, _ in save() }
    }

    private func save() {
        HotKeyPreferences.set(keyCode: keyCode, modifiers: modifiers)
    }
}
