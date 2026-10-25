use tauri::AppHandle;
use tauri_plugin_autostart::ManagerExt;

/// Whether ShotCubby starts when the user signs in (a value under the
/// per-user `Run` registry key, no administrator rights needed).
pub fn is_enabled(app: &AppHandle) -> bool {
    app.autolaunch().is_enabled().unwrap_or(false)
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
