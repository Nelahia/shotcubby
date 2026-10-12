import AppKit
import Carbon.HIToolbox

/// Persists the keyboard shortcut of each Spotlight command. Unlike the
/// global shortcut (`HotKeyPreferences`), these only apply while the
/// Spotlight panel is key, so they are matched against key events directly.
enum SpotlightShortcuts {
    private static let functionKeys: Set<UInt32> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111 // F1…F12
    ]

    private static func key(_ command: SpotlightCommand, _ field: String) -> String {
        "spotlightCommand.\(command.rawValue).\(field)"
    }

    static func shortcut(for command: SpotlightCommand) -> (keyCode: UInt32, modifiers: UInt32) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key(command, "keyCode")) != nil else {
            return command.defaultShortcut
        }
        return (
            UInt32(defaults.integer(forKey: key(command, "keyCode"))),
            UInt32(defaults.integer(forKey: key(command, "modifiers")))
        )
    }

    static func set(_ command: SpotlightCommand, keyCode: UInt32, modifiers: UInt32) {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: key(command, "keyCode"))
        defaults.set(Int(modifiers), forKey: key(command, "modifiers"))
    }

    static func reset(_ command: SpotlightCommand) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key(command, "keyCode"))
        defaults.removeObject(forKey: key(command, "modifiers"))
    }

    /// e.g. "⌘C" — the glyphs shown next to the command in the panel.
    static func display(_ command: SpotlightCommand) -> String {
        let shortcut = shortcut(for: command)
        return HotKeyPreferences.describe(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
    }

    /// The command whose shortcut this key event triggers, if any.
    static func command(for event: NSEvent) -> SpotlightCommand? {
        var keyCode = UInt32(event.keyCode)
        if keyCode == UInt32(kVK_ANSI_KeypadEnter) { keyCode = UInt32(kVK_Return) }
        let modifiers = carbonModifiers(from: event.modifierFlags)
        return SpotlightCommand.allCases.first { shortcut(for: $0) == (keyCode, modifiers) }
    }

    /// Another command already using this combination, if any.
    static func conflict(for command: SpotlightCommand, keyCode: UInt32, modifiers: UInt32) -> SpotlightCommand? {
        SpotlightCommand.allCases.first { $0 != command && shortcut(for: $0) == (keyCode, modifiers) }
    }

    /// A modifier keeps a shortcut from colliding with typing in the search
    /// field; only Return and the function keys may be bound bare.
    static func isBindable(keyCode: UInt32, modifiers: UInt32) -> Bool {
        modifiers != 0 || keyCode == UInt32(kVK_Return) || functionKeys.contains(keyCode)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }
}
