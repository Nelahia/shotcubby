use tauri::{AppHandle, Manager};

use crate::windows_ui;

#[tauri::command]
pub fn open_spotlight_from_popover(app: AppHandle) {
    if let Some(popover) = app.get_webview_window(windows_ui::POPOVER_LABEL) {
        let _ = popover.hide();
    }
    windows_ui::toggle_spotlight(&app);
}

#[tauri::command]
pub fn open_settings_window(app: AppHandle) {
    windows_ui::open_settings(&app);
}

#[tauri::command]
pub fn show_copy_toast(app: AppHandle) {
    windows_ui::show_copy_toast(&app);
}

#[tauri::command]
pub fn quit_app(app: AppHandle) {
    app.exit(0);
}
