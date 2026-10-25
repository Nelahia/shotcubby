import SwiftUI

/// One Settings line: a Spotlight command, its recorder field and a Reset
/// button. A combination another command already uses is refused.
struct SpotlightShortcutRow: View {
    let command: SpotlightCommand

    @State private var keyCode: UInt32
    @State private var modifiers: UInt32
    @State private var conflict: SpotlightCommand?

    init(command: SpotlightCommand) {
        self.command = command
        let current = SpotlightShortcuts.shortcut(for: command)
        _keyCode = State(initialValue: current.keyCode)
        _modifiers = State(initialValue: current.modifiers)
    }

    var body: some View {
        SettingsRow(
            title: command.title,
            subtitle: conflict.map { String(format: tr("Already used by %@"), $0.title) },
            subtitleColor: .red
        ) {
            HotKeyRecorderField(keyCode: $keyCode, modifiers: $modifiers, allowsBareKeys: true)
            Button("Reset") {
                SpotlightShortcuts.reset(command)
                conflict = nil
                load()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .onChange(of: keyCode) { _, _ in save() }
        .onChange(of: modifiers) { _, _ in save() }
    }

    private func load() {
        let current = SpotlightShortcuts.shortcut(for: command)
        keyCode = current.keyCode
        modifiers = current.modifiers
    }

    private func save() {
        let stored = SpotlightShortcuts.shortcut(for: command)
        // Already saved (or just reverted below): nothing to do, and the
        // conflict message must stay visible.
        if keyCode == stored.keyCode && modifiers == stored.modifiers { return }

        if let other = SpotlightShortcuts.conflict(for: command, keyCode: keyCode, modifiers: modifiers) {
            conflict = other
            load()
            return
        }
        conflict = nil
        SpotlightShortcuts.set(command, keyCode: keyCode, modifiers: modifiers)
    }
}
