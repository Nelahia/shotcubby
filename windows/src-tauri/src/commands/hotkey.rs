use tauri::AppHandle;

use crate::hotkey;
use crate::services::hotkey_preferences;

#[tauri::command]
pub fn get_hotkey() -> serde_json::Value {
    let current = hotkey_preferences::current();
    serde_json::json!({
        "value": current,
        "display": hotkey_preferences::describe(&current),
    })
}

#[tauri::command]
pub fn set_hotkey(app: AppHandle, hotkey_str: String) -> Result<String, String> {
    if !hotkey_preferences::has_modifier(&hotkey_str) {
        return Err("Shortcut needs at least one modifier key".into());
    }
    hotkey::apply(&app, &hotkey_str)?;
    hotkey_preferences::set(hotkey_str.clone());
    Ok(hotkey_preferences::describe(&hotkey_str))
}

#[tauri::command]
pub fn reset_hotkey(app: AppHandle) -> Result<serde_json::Value, String> {
    let default = hotkey_preferences::default();
    hotkey::apply(&app, &default)?;
    hotkey_preferences::reset();
    Ok(serde_json::json!({
        "value": default.clone(),
        "display": hotkey_preferences::describe(&default),
    }))
}
