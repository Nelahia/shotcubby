use crate::services::i18n::tr;
use serde::Serialize;
use tauri::{AppHandle, Emitter, State, WebviewWindow};
use tauri_plugin_opener::OpenerExt;

use crate::app_state::AppStateInner;
use crate::models::ScreenshotItem;
use crate::services;

#[derive(Serialize, Clone)]
struct RemovedPayload {
    id: String,
}

#[tauri::command]
pub fn list_screenshots(state: State<'_, AppStateInner>) -> Vec<ScreenshotItem> {
    state.screenshots.lock().unwrap().clone()
}

#[tauri::command]
pub fn get_thumbnail(path: String, max_px: u32) -> Option<String> {
    services::thumbnails::data_url(std::path::Path::new(&path), max_px)
}

#[tauri::command]
pub fn open_screenshot(app: AppHandle, path: String) -> Result<(), String> {
    app.opener().open_path(path, None::<&str>).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn reveal_screenshot(app: AppHandle, path: String) -> Result<(), String> {
    app.opener()
        .reveal_item_in_dir(path)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn copy_screenshot(state: State<'_, AppStateInner>, path: String) -> Result<(), String> {
    state
        .clipboard
        .copy_image_to_clipboard(std::path::Path::new(&path))
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn delete_screenshot(app: AppHandle, state: State<'_, AppStateInner>, id: String) -> Result<(), String> {
    let mut screenshots = state.screenshots.lock().unwrap();
    let Some(item) = screenshots.iter().find(|s| s.id == id).cloned() else {
        return Ok(());
    };
    if !services::storage::delete(&item.path) {
        return Err(tr("Could not move the file to the Recycle Bin"));
    }
    screenshots.retain(|s| s.id != id);
    drop(screenshots);

    let _ = app.emit("screenshot-removed", RemovedPayload { id });
    Ok(())
}

#[tauri::command]
pub fn rename_screenshot(
    app: AppHandle,
    state: State<'_, AppStateInner>,
    id: String,
    new_name: String,
) -> Result<ScreenshotItem, String> {
    services::screenshot_rename::rename(&app, &state.screenshots, &id, &new_name)
}

/// Drags a known screenshot's file out of the calling window. Only files the
/// app lists are accepted, whatever path the page sends.
#[tauri::command]
pub fn start_file_drag(window: WebviewWindow, state: State<'_, AppStateInner>, path: String) -> Result<(), String> {
    let path = std::path::PathBuf::from(path);
    let known = state.screenshots.lock().unwrap().iter().any(|s| s.path == path);
    if !known {
        return Err(tr("Unknown screenshot"));
    }
    services::file_drag::start(&window, path)
}
