use crate::services::i18n::tr;
use tauri::{AppHandle, State};
use tauri_plugin_opener::OpenerExt;

use crate::app_state::AppStateInner;
use crate::services::{self, AccessFailure};

#[tauri::command]
pub fn get_access_failure(state: State<'_, AppStateInner>) -> Option<AccessFailure> {
    *state.access_failure.lock().unwrap()
}

#[tauri::command]
pub fn get_vault_dir(state: State<'_, AppStateInner>) -> String {
    state.vault_dir().display().to_string()
}

#[tauri::command]
pub fn get_screenshot_dir(state: State<'_, AppStateInner>) -> String {
    state.screenshot_dir().display().to_string()
}

#[tauri::command]
pub fn choose_custom_folder(state: State<'_, AppStateInner>) -> Option<String> {
    let folder = rfd::FileDialog::new()
        .set_title(tr("Choose the folder ShotCubby should watch"))
        .pick_folder()?;

    services::folder_preferences::set_custom_directory(Some(folder.clone()));
    *state.access_failure.lock().unwrap() = None;
    state.watcher.lock().unwrap().restart();
    Some(folder.display().to_string())
}

#[tauri::command]
pub fn retry_screenshot_access(state: State<'_, AppStateInner>) {
    let mut failure = state.access_failure.lock().unwrap();
    if failure.is_none() {
        return;
    }
    *failure = None;
    drop(failure);
    state.watcher.lock().unwrap().start_watching();
}

#[tauri::command]
pub fn open_vault_folder(app: AppHandle, state: State<'_, AppStateInner>) -> Result<(), String> {
    app.opener()
        .open_path(state.vault_dir().display().to_string(), None::<&str>)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn open_windows_security(app: AppHandle) -> Result<(), String> {
    app.opener()
        .open_url(
            "ms-settings:windowsdefender-ransomwareprotection",
            None::<&str>,
        )
        .map_err(|e| e.to_string())
}
