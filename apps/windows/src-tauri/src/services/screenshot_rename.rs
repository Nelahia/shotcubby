use serde::Serialize;
use std::sync::Mutex;
use tauri::{AppHandle, Emitter};

use crate::models::{ScreenshotItem, Source};
use crate::services::storage;

#[derive(Serialize, Clone)]
struct RenamedPayload {
    old_id: String,
    item: ScreenshotItem,
}

/// Renames a listed screenshot, updates the list and tells the windows.
/// Shared by the manual rename command and AI naming, so both keep the
/// same rules.
pub fn rename(
    app: &AppHandle,
    screenshots: &Mutex<Vec<ScreenshotItem>>,
    id: &str,
    new_name: &str,
) -> Result<ScreenshotItem, String> {
    let mut list = screenshots.lock().unwrap();
    let Some(index) = list.iter().position(|s| s.id == id) else {
        return Err("Screenshot not found".into());
    };
    let item = &list[index];

    // A clipboard capture keeps its "(clipboard)" tag through a rename —
    // that suffix is how `ScreenshotItem::source` is derived on reload.
    let mut name = new_name.trim().to_string();
    if item.source == Source::Clipboard && !name.ends_with("(clipboard)") {
        name.push_str(" (clipboard)");
    }

    let Some(new_path) = storage::rename(&item.path, &name) else {
        return Err("Rename failed".into());
    };

    let renamed = ScreenshotItem::from_path(new_path);
    list[index] = renamed.clone();
    drop(list);

    let _ = app.emit(
        "screenshot-renamed",
        RenamedPayload {
            old_id: id.to_string(),
            item: renamed.clone(),
        },
    );
    Ok(renamed)
}
