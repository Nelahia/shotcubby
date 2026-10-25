use tauri::AppHandle;

use crate::services::launch_at_login;

#[tauri::command]
pub fn get_launch_at_login(app: AppHandle) -> bool {
    launch_at_login::is_enabled(&app)
}

#[tauri::command]
pub fn set_launch_at_login(app: AppHandle, enabled: bool) -> Result<(), String> {
    launch_at_login::set_enabled(&app, enabled)
}
