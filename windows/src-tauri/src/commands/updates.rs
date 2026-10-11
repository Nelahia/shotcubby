use crate::services::update_preferences;

#[tauri::command]
pub fn get_auto_update() -> bool {
    update_preferences::enabled()
}

#[tauri::command]
pub fn set_auto_update(enabled: bool) {
    update_preferences::set_enabled(enabled);
}
