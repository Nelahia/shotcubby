use super::config_store;
use std::path::PathBuf;

/// Persists the user's chosen custom screenshot folder. Mirrors
/// `FolderPreferences.swift`.
pub fn custom_directory() -> Option<PathBuf> {
    config_store::load().custom_directory
}

pub fn set_custom_directory(dir: Option<PathBuf>) {
    config_store::update(|config| config.custom_directory = dir);
}

/// The vault location the user moved it to, if any.
pub fn custom_vault() -> Option<PathBuf> {
    config_store::load().vault_directory
}

pub fn set_custom_vault(dir: Option<PathBuf>) {
    config_store::update(|config| config.vault_directory = dir);
}
