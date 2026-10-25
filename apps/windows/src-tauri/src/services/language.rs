use std::sync::atomic::{AtomicBool, Ordering};

use super::config_store;

static FRENCH: AtomicBool = AtomicBool::new(false);

/// The Windows primary language id of French (`LANG_FRENCH`).
const LANG_FRENCH: u16 = 0x0C;

/// What the user picked in Settings: `"auto"` follows Windows, `"en"` / `"fr"` force one.
pub fn preference() -> &'static str {
    match config_store::load().language.as_deref() {
        Some("fr") => "fr",
        Some("en") => "en",
        _ => "auto",
    }
}

/// The language the app speaks now: `"fr"`, or `"en"` for everything else.
pub fn code() -> &'static str {
    if is_french() { "fr" } else { "en" }
}

pub fn is_french() -> bool {
    FRENCH.load(Ordering::Relaxed)
}

/// Reads the saved choice (or Windows' display language) once, at startup.
pub fn init() {
    resolve(preference());
}

/// Saves the choice and applies it; anything but `auto`, `en` or `fr` is refused.
pub fn set_preference(preference: &str) -> Result<(), String> {
    let stored = match preference {
        "auto" => None,
        "en" | "fr" => Some(preference.to_string()),
        other => return Err(format!("Unknown language \"{other}\"")),
    };
    config_store::update(|config| config.language = stored);
    resolve(preference);
    Ok(())
}

fn resolve(preference: &str) {
    let french = match preference {
        "fr" => true,
        "en" => false,
        _ => system_is_french(),
    };
    FRENCH.store(french, Ordering::Relaxed);
}

fn system_is_french() -> bool {
    use windows::Win32::Globalization::GetUserDefaultUILanguage;
    // SAFETY: takes no arguments and only reads the user's setting.
    let language_id = unsafe { GetUserDefaultUILanguage() };
    language_id & 0x3FF == LANG_FRENCH
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_auto_english_and_french_are_accepted() {
        assert!(set_preference("klingon").is_err());
        assert!(set_preference("").is_err());
    }
}
