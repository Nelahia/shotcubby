use super::config_store;

/// Automatic updates are on unless the user switched them off in Settings.
pub fn enabled() -> bool {
    !config_store::load().auto_update_disabled
}

pub fn set_enabled(enabled: bool) {
    config_store::update(|config| config.auto_update_disabled = !enabled);
}
