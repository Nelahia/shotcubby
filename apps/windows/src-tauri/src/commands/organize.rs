use tauri::AppHandle;

use crate::services::{day_archive, organize_preferences};

#[tauri::command]
pub fn get_organize_by_day() -> bool {
    organize_preferences::enabled()
}

/// Turning it on files the existing past days straight away.
#[tauri::command]
pub fn set_organize_by_day(app: AppHandle, enabled: bool) {
    organize_preferences::set_enabled(enabled);
    day_archive::run_now(&app);
}
