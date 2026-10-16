use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Emitter};

use super::capture_dedup::{Claim, RecentCaptures};
use super::{auto_rename, capture, screenshot_discard, storage, AccessFailure};
use crate::models::{ScreenshotItem, Source};
use crate::windows_ui;

/// Where a new capture lands, whichever way it arrived. The Snipping Tool
/// saves a file AND copies the image, so both come in; only one is kept.
pub struct CaptureIntake {
    app: AppHandle,
    screenshots: Arc<Mutex<Vec<ScreenshotItem>>>,
    access_failure: Arc<Mutex<Option<AccessFailure>>>,
    recent: RecentCaptures,
}

impl CaptureIntake {
    pub fn new(
        app: AppHandle,
        screenshots: Arc<Mutex<Vec<ScreenshotItem>>>,
        access_failure: Arc<Mutex<Option<AccessFailure>>>,
    ) -> Self {
        CaptureIntake { app, screenshots, access_failure, recent: RecentCaptures::default() }
    }

    /// A screenshot file appeared in the screenshot folder.
    pub fn file_captured(&self, path: PathBuf) {
        let Some(moved) = storage::move_to_vault(&path) else {
            return;
        };
        self.recent.with_claim(&moved, Source::File, |claim| {
            // A capture lands fine even if the folder was previously flagged as
            // inaccessible (e.g. the user just fixed it).
            *self.access_failure.lock().unwrap() = None;
            let item = self.add(moved.clone());
            match claim {
                // The clipboard copy already played the sound and showed the
                // toast for this very capture: replace it, silently.
                Claim::TwinOf(clipboard_copy) => {
                    screenshot_discard::discard(&self.app, &self.screenshots, &clipboard_copy)
                }
                Claim::Fresh => self.give_feedback(&item),
            }
            auto_rename::spawn(self.app.clone(), self.screenshots.clone(), item);
        });
    }

    /// An image was copied to the clipboard and saved in the vault.
    pub fn clipboard_captured(&self, path: PathBuf) {
        self.recent.with_claim(&path, Source::Clipboard, |claim| {
            // The file copy of this capture already came in: keep that one.
            if let Claim::TwinOf(_) = claim {
                let _ = std::fs::remove_file(&path);
                return;
            }
            let item = self.add(path.clone());
            self.give_feedback(&item);
            auto_rename::spawn(self.app.clone(), self.screenshots.clone(), item);
        });
    }

    fn add(&self, path: PathBuf) -> ScreenshotItem {
        let item = ScreenshotItem::from_path(path);
        self.screenshots.lock().unwrap().insert(0, item.clone());
        let _ = self.app.emit("screenshot-added", &item);
        item
    }

    fn give_feedback(&self, item: &ScreenshotItem) {
        capture::play_capture_sound();
        windows_ui::show_toast(&self.app, item);
    }
}
