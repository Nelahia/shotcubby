use tauri::AppHandle;
use super::config_store;
use tauri_plugin_autostart::ManagerExt;

/// Whether ShotCubby starts when the user signs in (a value under the
/// per-user `Run` registry key, no administrator rights needed).
pub fn is_enabled(app: &AppHandle) -> bool {
    app.autolaunch().is_enabled().unwrap_or(false)
}

/// Opens ShotCubby at login by default: turned on once, the first time the
/// app runs, and never again so that switching it off in Settings sticks.
pub fn apply_default(app: &AppHandle) {
    let mut config = config_store::load();
    if config.login_default_applied {
        return;
    }
    let _ = set_enabled(app, true);
    config.login_default_applied = true;
    config_store::save(&config);
}

pub fn set_enabled(app: &AppHandle, enabled: bool) -> Result<(), String> {
    let launcher = app.autolaunch();
    if enabled {
        launcher.enable().map_err(|e| e.to_string())
    } else if launcher.is_enabled().unwrap_or(false) {
        launcher.disable().map_err(|e| e.to_string())
    } else {
        Ok(())
    }
}
