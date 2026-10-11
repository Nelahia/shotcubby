use crate::services::{update_preferences, updater};

#[tauri::command]
pub fn get_auto_update() -> bool {
    update_preferences::enabled()
}

#[tauri::command]
pub fn set_auto_update(enabled: bool) {
    update_preferences::set_enabled(enabled);
}

#[tauri::command]
pub fn get_update_status() -> updater::UpdateStatus {
    updater::status()
}

#[tauri::command]
pub async fn check_for_updates(app: tauri::AppHandle) -> updater::UpdateStatus {
    updater::check_and_install(&app).await
}
