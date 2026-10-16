use serde::Serialize;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Emitter};

use crate::models::ScreenshotItem;
use crate::services::capture_intake::CaptureIntake;
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
        let intake = Arc::new(CaptureIntake::new(
            app_handle.clone(),
            screenshots.clone(),
            access_failure.clone(),
        ));

        let watcher = {
            let intake_for_files = intake.clone();
            let on_new_screenshot = move |path: PathBuf| intake_for_files.file_captured(path);

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
            let intake_for_clipboard = intake.clone();
            ClipboardWatcher::new(move |path: PathBuf| intake_for_clipboard.clipboard_captured(path))
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
