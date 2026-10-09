import Foundation
import Carbon.HIToolbox

/// Persists the user's chosen global shortcut for opening Spotlight search.
///
/// Default is Option + Comma. Deliberately not Command + Comma: this is a
/// system-wide Carbon hotkey, so it would otherwise steal the near-universal
/// "Open Preferences" shortcut from whatever app is frontmost.
enum HotKeyPreferences {
    private static let keyCodeDefaultsKey = "spotlightHotKeyCode"
    private static let modifiersDefaultsKey = "spotlightHotKeyModifiers"

    static let didChangeNotification = Notification.Name("HotKeyPreferences.didChange")

    static let defaultKeyCode = UInt32(kVK_ANSI_Comma)
    static let defaultModifiers = UInt32(optionKey)

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
            UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓"
        ]
        if let name = named[keyCode] { return name }

        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "Key \(keyCode)" }

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
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
