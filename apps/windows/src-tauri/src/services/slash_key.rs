use std::sync::OnceLock;

use windows::Win32::UI::Input::KeyboardAndMouse::VkKeyScanW;

/// The search shortcut when the keyboard has no usable "/": the old fixed one.
const FALLBACK: &str = "Ctrl+/";

/// Ctrl plus whatever types "/" on this keyboard. The shortcut plugin binds a
/// physical key, and the one that prints "/" on a US keyboard prints ":" on a
/// French one, so a fixed `Ctrl+/` would be Ctrl+: there. The key is looked up by
/// what it types, with Shift where the layout needs it (French, German,
/// Spanish…). Worked out once per launch, so the shortcut cannot move under a
/// layout switch.
pub fn spotlight_default() -> &'static str {
    static COMBO: OnceLock<String> = OnceLock::new();
    COMBO.get_or_init(|| {
        let scan = unsafe { VkKeyScanW('/' as u16) };
        slash_combo(scan).unwrap_or_else(|| FALLBACK.to_string())
    })
}

/// `scan` is `VkKeyScanW`'s answer: the virtual key in the low byte, the
/// modifiers it needs in the high one (1 = Shift), `-1` when nothing types it.
fn slash_combo(scan: i16) -> Option<String> {
    if scan == -1 {
        return None;
    }
    let key = code_token((scan & 0xFF) as u16)?;
    match (scan >> 8) & 0xFF {
        0 => Some(format!("Ctrl+{key}")),
        1 => Some(format!("Ctrl+Shift+{key}")),
        // Ctrl or Alt (AltGr) needed to type it: not a combination to build on.
        _ => None,
    }
}

/// The key's name in the form the shortcut plugin parses.
fn code_token(vk: u16) -> Option<String> {
    let name = match vk {
        0x30..=0x39 => return Some(format!("Digit{}", vk - 0x30)),
        0x41..=0x5A => return Some(format!("Key{}", vk as u8 as char)),
        0xBA => "Semicolon",
        0xBB => "Equal",
        0xBC => "Comma",
        0xBD => "Minus",
        0xBE => "Period",
        0xBF => "Slash",
        0xC0 => "Backquote",
        0xDB => "BracketLeft",
        0xDC => "Backslash",
        0xDD => "BracketRight",
        0xDE => "Quote",
        _ => return None,
    };
    Some(name.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_key_of_its_own_gives_plain_ctrl() {
        assert_eq!(slash_combo(0x00BF).as_deref(), Some("Ctrl+Slash"));
    }

    #[test]
    fn a_shifted_slash_adds_shift() {
        // French: Shift + the ":" key. German and Spanish: Shift + 7.
        assert_eq!(slash_combo(0x01BF).as_deref(), Some("Ctrl+Shift+Slash"));
        assert_eq!(slash_combo(0x0137).as_deref(), Some("Ctrl+Shift+Digit7"));
    }

    #[test]
    fn a_slash_that_needs_altgr_or_nothing_has_no_combo() {
        assert_eq!(slash_combo(0x06BF), None);
        assert_eq!(slash_combo(-1), None);
    }
}
