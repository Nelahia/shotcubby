import AppKit
import Carbon.HIToolbox

/// Persists the user's chosen global shortcut for opening Spotlight search.
///
/// Default is Command + Slash (see `defaultKeyCode` for keyboards without a bare
/// slash). This is a system-wide Carbon hotkey, so it
/// would otherwise steal whatever that combo already does — checked against
/// Apple's own Command-key shortcut list (support.apple.com/102650): every
/// letter is claimed by something, but ⌘/ is about as obscure as it gets
/// (toggles the Finder window status bar, a feature most people have never
/// touched), and it's right next to Comma on the keyboard.
enum HotKeyPreferences {
    private static let keyCodeDefaultsKey = "spotlightHotKeyCode"
    private static let modifiersDefaultsKey = "spotlightHotKeyModifiers"

    static let didChangeNotification = Notification.Name("HotKeyPreferences.didChange")

    /// A key code is a physical key, and the one that prints "/" on a US keyboard
    /// prints "=" on a French one, which would give ⌘= (zoom in) to ShotCubby in
    /// every app. So ⌘/ is only the default where "/" is typed without Shift;
    /// elsewhere (French, German, Spanish…) it is ⌘⇧Space. Worked out once per
    /// launch, so the shortcut cannot move under a layout switch.
    static let defaultKeyCode: UInt32 = slashKeyCode ?? UInt32(kVK_Space)
    static let defaultModifiers: UInt32 = slashKeyCode == nil ? UInt32(cmdKey | shiftKey) : UInt32(cmdKey)

    /// The main-block key that prints "/" with no modifier on the current layout.
    /// The numeric keypad is left out: a laptop has none.
    private static let slashKeyCode: UInt32? = {
        let keypad: Set<UInt32> = [65, 67, 69, 71, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92]
        return (UInt32(0)..<UInt32(128)).first { !keypad.contains($0) && translatedChar(for: $0) == "/" }
    }()

    static var keyCode: UInt32 {
        guard UserDefaults.standard.object(forKey: keyCodeDefaultsKey) != nil else { return defaultKeyCode }
        return UInt32(UserDefaults.standard.integer(forKey: keyCodeDefaultsKey))
    }

    static var modifiers: UInt32 {
        guard UserDefaults.standard.object(forKey: modifiersDefaultsKey) != nil else { return defaultModifiers }
        return UInt32(UserDefaults.standard.integer(forKey: modifiersDefaultsKey))
    }

    static func set(keyCode: UInt32, modifiers: UInt32) {
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodeDefaultsKey)
        UserDefaults.standard.set(Int(modifiers), forKey: modifiersDefaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: keyCodeDefaultsKey)
        UserDefaults.standard.removeObject(forKey: modifiersDefaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    /// Human-readable form of a keycode + Carbon modifier mask, e.g. "⌥`"
    /// — resolved against the CURRENT keyboard layout, so it always shows
    /// the glyph actually printed on that physical key.
    static func describe(keyCode: UInt32, modifiers: UInt32) -> String {
        var prefix = ""
        if modifiers & UInt32(controlKey) != 0 { prefix += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { prefix += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { prefix += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { prefix += "⌘" }
        return prefix + keyGlyph(for: keyCode)
    }

    private static func keyGlyph(for keyCode: UInt32) -> String {
        let named: [UInt32: String] = [
            UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥",
            UInt32(kVK_Delete): "⌫", UInt32(kVK_Escape): "⎋",
            UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
            UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
            UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4",
            UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6", UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8",
            UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12"
        ]
        if let name = named[keyCode] { return name }
        guard let char = translatedChar(for: keyCode) else { return "Key \(keyCode)" }
        return char.uppercased()
    }

    /// NSMenuItem-compatible key equivalent for a Carbon keycode + modifier
    /// mask, so a status-bar/context menu item can display the real
    /// configured shortcut next to its title. Display only — the global
    /// hotkey itself is still handled by Carbon's RegisterEventHotKey.
    static func menuKeyEquivalent(keyCode: UInt32, modifiers: UInt32) -> (key: String, mask: NSEvent.ModifierFlags) {
        var mask: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { mask.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { mask.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { mask.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { mask.insert(.command) }

        let named: [UInt32: String] = [
            UInt32(kVK_Space): " ", UInt32(kVK_Return): "\r", UInt32(kVK_Tab): "\t",
            UInt32(kVK_Delete): "\u{8}", UInt32(kVK_Escape): "\u{1b}",
            UInt32(kVK_LeftArrow): "\u{F702}", UInt32(kVK_RightArrow): "\u{F703}",
            UInt32(kVK_UpArrow): "\u{F700}", UInt32(kVK_DownArrow): "\u{F701}"
        ]
        let key = named[keyCode] ?? translatedChar(for: keyCode)?.lowercased() ?? ""
        return (key, mask)
    }

    /// Resolves a Carbon keycode to the character printed on that physical
    /// key under the CURRENT keyboard layout.
    private static func translatedChar(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = layoutData.withUnsafeBytes { rawBuffer -> OSStatus in
            guard let keyLayoutPtr = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(
                keyLayoutPtr, UInt16(keyCode), UInt16(kUCKeyActionDisplay),
                0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, 4, &length, &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
