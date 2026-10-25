use super::config_store;
use super::hotkey_action::HotkeyAction;

const MODIFIER_TOKENS: &[&str] = &[
    "CTRL",
    "CONTROL",
    "ALT",
    "OPTION",
    "SHIFT",
    "SUPER",
    "CMD",
    "COMMAND",
    "WIN",
];

pub fn current(action: HotkeyAction) -> String {
    config_store::load()
        .hotkeys
        .get(action.id())
        .cloned()
        .unwrap_or_else(|| default(action))
}

pub fn default(action: HotkeyAction) -> String {
    action.default_hotkey().to_string()
}

/// Whether a combo can safely be bound globally. A modifier keeps it from
/// colliding with plain typing; keys that never type anything (function
/// keys, PrintScreen...) are fine on their own, which is what lets a
/// capture shortcut be a bare `PrintScreen`.
pub fn is_allowed(hotkey: &str) -> bool {
    let has_modifier = hotkey
        .split('+')
        .any(|token| MODIFIER_TOKENS.contains(&token.trim().to_uppercase().as_str()));
    has_modifier || is_standalone_key(hotkey.trim())
}

fn is_standalone_key(key: &str) -> bool {
    let upper = key.to_uppercase();
    let is_function_key = upper
        .strip_prefix('F')
        .and_then(|n| n.parse::<u8>().ok())
        .is_some_and(|n| (1..=24).contains(&n));
    is_function_key || matches!(upper.as_str(), "PRINTSCREEN" | "SCROLLLOCK" | "PAUSE")
}

pub fn set(action: HotkeyAction, hotkey: String) {
    config_store::update(|config| {
        config.hotkeys.insert(action.id().to_string(), hotkey);
    });
}

pub fn reset(action: HotkeyAction) {
    config_store::update(|config| {
        config.hotkeys.remove(action.id());
    });
}

/// Human-readable form for display in the Settings field, e.g. "Ctrl + Alt + /".
///
/// Tokens come from two sources that both need prettifying: the recorder
/// field in Settings sends raw DOM `KeyboardEvent.code` values (`"KeyS"`,
/// `"Digit1"`, `"BracketLeft"`...), and `DEFAULT_HOTKEY` uses the shorter
/// literal forms the `global-hotkey` crate also accepts (`"/"`, `"Slash"`).
pub fn describe(hotkey: &str) -> String {
    hotkey
        .split('+')
        .map(|raw| describe_token(raw.trim()))
        .collect::<Vec<_>>()
        .join(" + ")
}

fn describe_token(token: &str) -> String {
    let upper = token.to_uppercase();

    if let Some(letter) = upper.strip_prefix("KEY") {
        return letter.to_string();
    }
    if let Some(digit) = upper.strip_prefix("DIGIT") {
        return digit.to_string();
    }

    match upper.as_str() {
        "CTRL" | "CONTROL" => "Ctrl".to_string(),
        "ALT" | "OPTION" => "Alt".to_string(),
        "SHIFT" => "Shift".to_string(),
        "SUPER" | "WIN" | "CMD" | "COMMAND" | "META" => "Win".to_string(),
        "SLASH" => "/".to_string(),
        "COMMA" => ",".to_string(),
        "PERIOD" => ".".to_string(),
        "BRACKETLEFT" => "[".to_string(),
        "BRACKETRIGHT" => "]".to_string(),
        "BACKSLASH" => "\\".to_string(),
        "BACKQUOTE" => "`".to_string(),
        "QUOTE" => "'".to_string(),
        "SEMICOLON" => ";".to_string(),
        "MINUS" => "-".to_string(),
        "EQUAL" => "=".to_string(),
        "ARROWUP" | "UP" => "\u{2191}".to_string(),
        "ARROWDOWN" | "DOWN" => "\u{2193}".to_string(),
        "ARROWLEFT" | "LEFT" => "\u{2190}".to_string(),
        "ARROWRIGHT" | "RIGHT" => "\u{2192}".to_string(),
        "SPACE" => "Space".to_string(),
        "PRINTSCREEN" => "PrtScn".to_string(),
        "BACKSPACE" => "\u{232b}".to_string(),
        other if other.chars().count() == 1 => other.to_string(),
        other => {
            let mut chars = other.chars();
            match chars.next() {
                Some(first) => first.to_string() + &chars.as_str().to_lowercase(),
                None => String::new(),
            }
        }
    }
}
