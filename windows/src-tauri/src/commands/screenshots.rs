use serde::Serialize;
use tauri::{AppHandle, Emitter, State};
use tauri_plugin_opener::OpenerExt;

use crate::app_state::AppStateInner;
use crate::models::{ScreenshotItem, Source};
use crate::services;

#[derive(Serialize, Clone)]
struct RemovedPayload {
    id: String,
}

#[derive(Serialize, Clone)]
struct RenamedPayload {
    old_id: String,
    item: ScreenshotItem,
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
        return Err("Could not move the file to the Recycle Bin".into());
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
    let mut screenshots = state.screenshots.lock().unwrap();
    let Some(index) = screenshots.iter().position(|s| s.id == id) else {
        return Err("Screenshot not found".into());
    };
    let item = &screenshots[index];

    // A clipboard capture keeps its "(clipboard)" tag through a rename —
    // that suffix is how `ScreenshotItem::source` is derived on reload.
    let mut sanitized = new_name.trim().to_string();
    if item.source == Source::Clipboard && !sanitized.ends_with("(clipboard)") {
        sanitized.push_str(" (clipboard)");
    }

    let Some(new_path) = services::storage::rename(&item.path, &sanitized) else {
        return Err("Rename failed".into());
    };

    let renamed = ScreenshotItem::from_path(new_path);
    screenshots[index] = renamed.clone();
    drop(screenshots);

    let _ = app.emit(
        "screenshot-renamed",
        RenamedPayload {
            old_id: id,
            item: renamed.clone(),
        },
    );
    Ok(renamed)
}
