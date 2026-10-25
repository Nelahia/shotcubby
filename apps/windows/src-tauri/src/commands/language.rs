use tauri::{AppHandle, Emitter};

use crate::services::language;

/// The language the app speaks now (`"en"` or `"fr"`), after the choice and Windows' language.
#[tauri::command]
pub fn get_language() -> &'static str {
    language::code()
}

/// What Settings shows selected: `"auto"`, `"en"` or `"fr"`.
#[tauri::command]
pub fn get_language_preference() -> &'static str {
    language::preference()
}

/// Saves the choice, redraws the tray menu and tells every window to reload.
#[tauri::command]
pub fn set_language_preference(app: AppHandle, preference: String) -> Result<(), String> {
    language::set_preference(&preference)?;
    crate::refresh_tray(&app);
    let _ = app.emit("language-changed", language::code());
    Ok(())
}
