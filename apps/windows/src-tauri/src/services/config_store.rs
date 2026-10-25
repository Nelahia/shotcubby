use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard, OnceLock};

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
    /// Dark appearance. Stored as a flag so the default (key absent) is light.
    #[serde(default)]
    pub dark_theme: bool,
    /// Set once the first-run "open at login" default has been applied, so a
    /// later switch-off by the user is never undone.
    #[serde(default)]
    pub login_default_applied: bool,
    /// The interface language the user forced (`"en"` or `"fr"`); absent follows Windows.
    #[serde(default)]
    pub language: Option<String>,
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

/// Serializes every read and write of the file: a setting changed on one thread
/// can no longer be undone by another thread saving an older copy, and nobody
/// reads the file halfway through a write.
static LOCK: Mutex<()> = Mutex::new(());

fn lock() -> MutexGuard<'static, ()> {
    LOCK.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn parse(path: &Path) -> Option<AppConfig> {
    serde_json::from_str(&std::fs::read_to_string(path).ok()?).ok()
}

fn backup_of(path: &Path) -> PathBuf {
    path.with_extension("json.bak")
}

/// The file, or its last good copy when it is empty or damaged. A file that
/// cannot be read at all is kept as `.corrupt` before the defaults are used,
/// so a lost setting can be traced instead of vanishing.
fn read_from(path: &Path) -> AppConfig {
    let mut config = parse(path).or_else(|| parse(&backup_of(path))).unwrap_or_else(|| {
        if path.exists() {
            let _ = std::fs::copy(path, path.with_extension("json.corrupt"));
        }
        AppConfig::default()
    });
    if let Some(legacy) = config.hotkey.take() {
        config.hotkeys.entry("spotlight".to_string()).or_insert(legacy);
    }
    config
}

/// Writes a temporary file and renames it over the real one, so the config is
/// never left truncated, even if the app is killed mid-write (an update does
/// that). The previous good file is kept as `.bak`.
fn write_to(path: &Path, config: &AppConfig) {
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let Ok(json) = serde_json::to_string_pretty(config) else { return };
    if parse(path).is_some() {
        let _ = std::fs::copy(path, backup_of(path));
    }
    let temporary = path.with_extension("json.tmp");
    if std::fs::write(&temporary, json).is_err() || std::fs::rename(&temporary, path).is_err() {
        let _ = std::fs::remove_file(&temporary);
    }
}

pub fn load() -> AppConfig {
    let _guard = lock();
    read_from(&config_path())
}

/// Reads, changes and writes the config as one step; returns what `change` returns.
pub fn update<R>(change: impl FnOnce(&mut AppConfig) -> R) -> R {
    let _guard = lock();
    let path = config_path();
    let mut config = read_from(&path);
    let result = change(&mut config);
    write_to(&path, &config);
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_config(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("shotcubby-config-{}-{name}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir.join("config.json")
    }

    #[test]
    fn what_is_written_is_read_back() {
        let path = temp_config("roundtrip");
        write_to(&path, &AppConfig { ai_rename_enabled: true, ..AppConfig::default() });
        assert!(read_from(&path).ai_rename_enabled);
    }

    #[test]
    fn an_emptied_file_falls_back_to_the_last_good_copy() {
        let path = temp_config("emptied");
        write_to(&path, &AppConfig { ai_rename_enabled: true, ..AppConfig::default() });
        write_to(&path, &AppConfig { ai_rename_enabled: true, dark_theme: true, ..AppConfig::default() });
        std::fs::write(&path, "").unwrap();
        assert!(read_from(&path).ai_rename_enabled, "the setting must survive a truncated file");
    }

    #[test]
    fn an_unreadable_file_with_no_copy_is_kept_aside() {
        let path = temp_config("corrupt");
        std::fs::write(&path, "{ not json").unwrap();
        assert!(!read_from(&path).ai_rename_enabled);
        assert!(path.with_extension("json.corrupt").exists());
    }

    #[test]
    fn no_temporary_file_is_left_behind() {
        let path = temp_config("tmp");
        write_to(&path, &AppConfig::default());
        assert!(!path.with_extension("json.tmp").exists());
    }
}
