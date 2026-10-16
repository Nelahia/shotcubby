use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::PathBuf;
use std::sync::OnceLock;

/// Single small JSON file backing both `folder_preferences` and
/// `hotkey_preferences` — the Windows analog of `UserDefaults`, which both
/// preference namespaces shared on macOS too.
#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub custom_directory: Option<PathBuf>,
    /// Where the vault lives when the user moved it; absent means the default.
    #[serde(default)]
    pub vault_directory: Option<PathBuf>,
    /// Stored negated so the default (key absent) means "updates on".
    #[serde(default)]
    pub auto_update_disabled: bool,
    /// Stored negated so the default (key absent) means "file past days into
    /// `YYYY-MM-DD` folders".
    #[serde(default)]
    pub organize_by_day_disabled: bool,
    /// AI naming: stored as is, since the default (key absent) is "off".
    /// The API key itself is never here, see `api_key_store`.
    #[serde(default)]
    pub ai_rename_enabled: bool,
    #[serde(default)]
    pub ai_rename_provider: Option<String>,
    /// The user's own naming convention, sent to the model with every screenshot.
    #[serde(default)]
    pub ai_rename_instructions: Option<String>,
    /// Shortcut per `HotkeyAction::id()`.
    #[serde(default)]
    pub hotkeys: BTreeMap<String, String>,
    /// Pre-`hotkeys` field: the single Spotlight shortcut. Read once on
    /// load and folded into `hotkeys`, never written back.
    #[serde(default, skip_serializing)]
    hotkey: Option<String>,
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
    let mut config: AppConfig = std::fs::read_to_string(config_path())
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default();
    if let Some(legacy) = config.hotkey.take() {
        config.hotkeys.entry("spotlight".to_string()).or_insert(legacy);
    }
    config
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
