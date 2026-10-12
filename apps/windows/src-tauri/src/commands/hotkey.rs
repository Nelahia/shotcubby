use tauri::AppHandle;

use crate::hotkey;
use crate::services::hotkey_action::HotkeyAction;
use crate::services::hotkey_preferences;

fn parse_action(id: &str) -> Result<HotkeyAction, String> {
    HotkeyAction::from_id(id).ok_or_else(|| format!("Unknown shortcut '{id}'"))
}

#[tauri::command]
pub fn get_hotkeys() -> Vec<serde_json::Value> {
    HotkeyAction::ALL
        .into_iter()
        .map(|action| {
            serde_json::json!({
                "action": action.id(),
                "label": action.label(),
                "display": hotkey_preferences::describe(&hotkey_preferences::current(action)),
            })
        })
        .collect()
}

#[tauri::command]
pub fn set_hotkey(app: AppHandle, action: String, hotkey_str: String) -> Result<String, String> {
    let action = parse_action(&action)?;
    if !hotkey_preferences::is_allowed(&hotkey_str) {
        return Err("Shortcut needs a modifier key (or be a function / PrintScreen key)".into());
    }
    hotkey::apply(&app, action, &hotkey_str)
        .map_err(|e| format!("Shortcut unavailable (already in use?): {e}"))?;
    hotkey_preferences::set(action, hotkey_str.clone());
    Ok(hotkey_preferences::describe(&hotkey_str))
}

#[tauri::command]
pub fn reset_hotkey(app: AppHandle, action: String) -> Result<String, String> {
    let action = parse_action(&action)?;
    let default = hotkey_preferences::default(action);
    hotkey::apply(&app, action, &default)
        .map_err(|e| format!("Default shortcut unavailable (already in use?): {e}"))?;
    hotkey_preferences::reset(action);
    Ok(hotkey_preferences::describe(&default))
}
