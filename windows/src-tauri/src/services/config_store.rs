use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::OnceLock;

/// Single small JSON file backing both `folder_preferences` and
/// `hotkey_preferences` — the Windows analog of `UserDefaults`, which both
/// preference namespaces shared on macOS too.
#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub custom_directory: Option<PathBuf>,
    pub hotkey: Option<String>,
}

fn config_path() -> PathBuf {
    static PATH: OnceLock<PathBuf> = OnceLock::new();
    PATH.get_or_init(|| {
        dirs::config_dir()
            .unwrap_or_else(std::env::temp_dir)
            .join("ShotCubby")
            .join("config.json")
    })
    .clone()
}

pub fn load() -> AppConfig {
    std::fs::read_to_string(config_path())
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

pub fn save(config: &AppConfig) {
    let path = config_path();
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(config) {
        let _ = std::fs::write(path, json);
    }
}
