use chrono::{DateTime, Local, NaiveDate};
use std::path::Path;
use std::time::{Duration, SystemTime};
use tauri::{AppHandle, Emitter, Manager};

use super::{organize_preferences, storage};
use crate::app_state::AppStateInner;

/// A day only rolls over once, so a slow poll is enough to file yesterday's
/// captures soon after midnight without a precise timer.
const CHECK_EVERY: Duration = Duration::from_secs(10 * 60);

/// Files every screenshot taken before today from the vault's root into a
/// `YYYY-MM-DD` folder named after its day. Today's stay at the root, so they
/// remain where they have always been until the day is over. Returns whether
/// anything moved. Mirrors `ScreenshotStorage.archivePastDays`.
fn archive_past_days() -> bool {
    let vault = storage::vault_dir();
    let today = Local::now().date_naive();
    let mut moved = false;

    for path in storage::children(&vault) {
        if !path.is_file() || !storage::is_image_file(&path) {
            continue;
        }
        let Some(day) = capture_day(&path).filter(|day| *day < today) else {
            continue;
        };
        let folder = vault.join(day.format(storage::DAY_FOLDER_FORMAT).to_string());
        if std::fs::create_dir_all(&folder).is_err() {
            continue;
        }
        let destination = storage::unique_destination(
            &folder,
            &storage::file_stem(&path),
            &storage::extension(&path),
        );
        moved |= std::fs::rename(&path, destination).is_ok();
    }
    moved
}

fn capture_day(path: &Path) -> Option<NaiveDate> {
    let metadata = std::fs::metadata(path).ok()?;
    let time: SystemTime = metadata.created().or_else(|_| metadata.modified()).ok()?;
    Some(DateTime::<Local>::from(time).date_naive())
}

/// Files the past days if the option is on, then tells the windows to reload.
pub fn run_now(app: &AppHandle) {
    if !organize_preferences::enabled() || !archive_past_days() {
        return;
    }
    let state = app.state::<AppStateInner>();
    *state.screenshots.lock().unwrap() = storage::load_all();
    let _ = app.emit("screenshots-reloaded", ());
}

/// Runs at launch, then every few minutes for as long as the app is open.
pub fn start(app: AppHandle) {
    std::thread::spawn(move || loop {
        run_now(&app);
        std::thread::sleep(CHECK_EVERY);
    });
}
