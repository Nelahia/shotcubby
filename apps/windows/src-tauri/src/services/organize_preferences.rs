use super::config_store;

/// Whether past days' screenshots are filed into dated folders. On unless
/// the user switched it off in Settings. Mirrors `OrganizePreferences.swift`.
pub fn enabled() -> bool {
    !config_store::load().organize_by_day_disabled
}

pub fn set_enabled(enabled: bool) {
    let mut config = config_store::load();
    config.organize_by_day_disabled = !enabled;
    config_store::save(&config);
}
