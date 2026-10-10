use super::config_store;
use std::path::PathBuf;

/// Persists the user's chosen custom screenshot folder. Mirrors
/// `FolderPreferences.swift`.
pub fn custom_directory() -> Option<PathBuf> {
    config_store::load().custom_directory
}

pub fn set_custom_directory(dir: Option<PathBuf>) {
    let mut config = config_store::load();
    config.custom_directory = dir;
    config_store::save(&config);
}
