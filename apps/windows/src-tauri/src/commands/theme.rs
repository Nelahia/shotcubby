use tauri::{AppHandle, Emitter};

use crate::services::theme_preferences;

#[tauri::command]
pub fn get_theme() -> &'static str {
    theme_preferences::current()
}

/// Saves the appearance and tells every window, so they all switch at once.
#[tauri::command]
pub fn set_theme(app: AppHandle, theme: String) -> Result<(), String> {
    let applied = theme_preferences::set(&theme)?;
    let _ = app.emit("theme-changed", applied);
    Ok(())
}
