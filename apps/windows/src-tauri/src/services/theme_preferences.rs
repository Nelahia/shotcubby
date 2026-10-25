use super::config_store;

const LIGHT: &str = "light";
const DARK: &str = "dark";

/// The appearance the user picked, light unless they switched to dark in
/// Settings. Mirrors `AppearancePreferences.swift`.
pub fn current() -> &'static str {
    if config_store::load().dark_theme { DARK } else { LIGHT }
}

/// Saves `theme` (`"light"` or `"dark"`) and returns it; anything else is refused.
pub fn set(theme: &str) -> Result<&'static str, String> {
    let (name, dark) = match theme {
        LIGHT => (LIGHT, false),
        DARK => (DARK, true),
        other => return Err(format!("Unknown theme \"{other}\"")),
    };
    let mut config = config_store::load();
    config.dark_theme = dark;
    config_store::save(&config);
    Ok(name)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_light_and_dark_are_accepted() {
        assert!(set("sepia").is_err());
        assert!(set("").is_err());
    }
}
