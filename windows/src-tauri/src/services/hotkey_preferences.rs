use super::config_store;

/// Default global shortcut for toggling the Spotlight-style search panel.
/// Fully user-customizable from Settings.
pub const DEFAULT_HOTKEY: &str = "Ctrl+/";

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

pub fn current() -> String {
    config_store::load().hotkey.unwrap_or_else(default)
}

pub fn default() -> String {
    DEFAULT_HOTKEY.to_string()
}

/// Rejects combos with no modifier — the same requirement the Mac recorder
/// field enforces so a shortcut can never collide with plain typing.
pub fn has_modifier(hotkey: &str) -> bool {
    hotkey
        .split('+')
        .any(|token| MODIFIER_TOKENS.contains(&token.trim().to_uppercase().as_str()))
}

pub fn set(hotkey: String) {
    let mut config = config_store::load();
    config.hotkey = Some(hotkey);
    config_store::save(&config);
}

pub fn reset() {
    let mut config = config_store::load();
    config.hotkey = None;
    config_store::save(&config);
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
