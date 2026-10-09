import SwiftUI

struct SettingsView: View {
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
            } footer: {
                Text("Click the field, then press a key combination with at least one modifier (⌘ ⌥ ⌃ ⇧). Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 140)
        .onChange(of: keyCode) { _, _ in save() }
        .onChange(of: modifiers) { _, _ in save() }
    }

    private func save() {
        HotKeyPreferences.set(keyCode: keyCode, modifiers: modifiers)
    }
}
