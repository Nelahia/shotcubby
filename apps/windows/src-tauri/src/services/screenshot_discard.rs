use serde::Serialize;
use std::path::Path;
use std::sync::Mutex;
use tauri::{AppHandle, Emitter};

use crate::models::ScreenshotItem;

#[derive(Serialize, Clone)]
struct RemovedPayload {
    id: String,
}

/// Drops a copy the app made itself (the clipboard twin of a capture): the
/// file is deleted outright rather than sent to the Recycle Bin, and the list
/// and the windows are told. Not for the user's own files.
pub fn discard(app: &AppHandle, screenshots: &Mutex<Vec<ScreenshotItem>>, path: &Path) {
    let id = path.to_string_lossy().into_owned();
    screenshots.lock().unwrap().retain(|s| s.id != id);
    let _ = std::fs::remove_file(path);
    let _ = app.emit("screenshot-removed", RemovedPayload { id });
}
