use super::config_store;

/// Automatic updates are on unless the user switched them off in Settings.
pub fn enabled() -> bool {
    !config_store::load().auto_update_disabled
}

pub fn set_enabled(enabled: bool) {
    let mut config = config_store::load();
    config.auto_update_disabled = !enabled;
    config_store::save(&config);
}
