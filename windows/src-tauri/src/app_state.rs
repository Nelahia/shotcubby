use serde::Serialize;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Emitter};

use crate::models::ScreenshotItem;
use crate::services::{self, AccessFailure, ClipboardWatcher, ScreenshotWatcher};

/// Mirrors `AppState.swift`: the in-memory source of truth the frontend
/// windows read through commands and get pushed updates for via events.
pub struct AppStateInner {
    pub screenshots: Arc<Mutex<Vec<ScreenshotItem>>>,
    pub access_failure: Arc<Mutex<Option<AccessFailure>>>,
    pub watcher: Mutex<ScreenshotWatcher>,
    pub clipboard: ClipboardWatcher,
}

#[derive(Serialize, Clone)]
struct AccessFailurePayload {
    failure: Option<AccessFailure>,
}

impl AppStateInner {
    pub fn init(app_handle: AppHandle) -> Self {
        services::storage::ensure_vault_exists();

        let screenshots = Arc::new(Mutex::new(services::storage::load_all()));
        let access_failure = Arc::new(Mutex::new(None));

        let watcher = {
            let screenshots_for_new = screenshots.clone();
            let app_handle_for_new = app_handle.clone();
            let access_failure_for_new = access_failure.clone();

            let on_new_screenshot = move |path: PathBuf| {
                let Some(moved) = services::storage::move_to_vault(&path) else {
                    return;
                };
                let item = ScreenshotItem::from_path(moved);
                screenshots_for_new.lock().unwrap().insert(0, item.clone());
                // A capture lands fine even if the folder was previously
                // flagged as inaccessible (e.g. the user just fixed it).
                *access_failure_for_new.lock().unwrap() = None;
                let _ = app_handle_for_new.emit("screenshot-added", &item);
            };

            let access_failure_for_failed = access_failure.clone();
            let app_handle_for_failed = app_handle.clone();
            let on_access_failed = move |failure: AccessFailure| {
                *access_failure_for_failed.lock().unwrap() = Some(failure);
                let _ = app_handle_for_failed.emit(
                    "access-failure-changed",
                    AccessFailurePayload {
                        failure: Some(failure),
                    },
                );
            };

            ScreenshotWatcher::new(on_new_screenshot, on_access_failed)
        };

        let clipboard = {
            let screenshots_for_clipboard = screenshots.clone();
            let app_handle_for_clipboard = app_handle.clone();

            let on_new_image = move |path: PathBuf| {
                let item = ScreenshotItem::from_path(path);
                screenshots_for_clipboard.lock().unwrap().insert(0, item.clone());
                let _ = app_handle_for_clipboard.emit("screenshot-added", &item);
            };

            ClipboardWatcher::new(on_new_image)
        };

        AppStateInner {
            screenshots,
            access_failure,
            watcher: Mutex::new(watcher),
            clipboard,
        }
    }

    pub fn start(&self) {
        self.watcher.lock().unwrap().start_watching();
        self.clipboard.start_watching();
    }

    pub fn vault_dir(&self) -> PathBuf {
        services::storage::vault_dir()
    }

    pub fn screenshot_dir(&self) -> PathBuf {
        self.watcher.lock().unwrap().screenshot_dir().to_path_buf()
    }
}
