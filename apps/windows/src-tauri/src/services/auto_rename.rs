use crate::services::i18n::tr;
use serde::Serialize;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tauri::AppHandle;

use super::llm::{self, Failure, Kind};
use super::{ai_rename_preferences, api_key_store, screenshot_rename};
use crate::models::{ScreenshotItem, Source};

/// A clipboard copy may be the twin of a file capture that is about to
/// replace it (see `capture_dedup`): wait for that before spending a request.
const TWIN_WAIT: Duration = Duration::from_secs(3);

/// What the last smart-naming attempt did, shown in Settings so a failure
/// (quota, network, a bad key) is never invisible. `kind` is set on failures.
#[derive(Clone, Serialize)]
pub struct Outcome {
    pub ok: bool,
    pub kind: Option<Kind>,
    pub message: String,
}

static LAST_RESULT: Mutex<Option<Outcome>> = Mutex::new(None);

pub fn last_result() -> Option<Outcome> {
    LAST_RESULT.lock().unwrap().clone()
}

fn record_ok(message: String) {
    *LAST_RESULT.lock().unwrap() = Some(Outcome { ok: true, kind: None, message });
}

fn record_failure(failure: Failure) {
    *LAST_RESULT.lock().unwrap() = Some(Outcome {
        ok: false,
        kind: Some(failure.kind),
        message: failure.message,
    });
}

/// AI naming for a capture that just landed in the vault. Runs on its own
/// thread so the capture shows up at once; any failure leaves the name as is.
/// A manual rename (or a day-folder move) while the request is in flight
/// changes the item's id, so the late answer finds nothing to rename.
pub fn spawn(app: AppHandle, screenshots: Arc<Mutex<Vec<ScreenshotItem>>>, item: ScreenshotItem) {
    let ai_rename_preferences::Preferences { enabled, provider, instructions } = ai_rename_preferences::load();
    if !enabled {
        return;
    }
    let Some(key) = api_key_store::get(provider) else {
        return record_failure(Failure::other(tr("No API key saved")));
    };

    std::thread::spawn(move || {
        if item.source == Source::Clipboard {
            std::thread::sleep(TWIN_WAIT);
            if !screenshots.lock().unwrap().iter().any(|s| s.id == item.id) {
                return;
            }
        }
        let Some(jpeg) = llm::prepare_jpeg(&item.path) else {
            return record_failure(Failure::other(tr("Could not read the screenshot")));
        };
        let title = match provider.title_for(&key, &jpeg, instructions.as_deref()) {
            Ok(title) if !title.is_empty() => title,
            Ok(_) => return record_failure(Failure::other(tr("The provider returned no title"))),
            Err(failure) => return record_failure(failure),
        };
        match screenshot_rename::rename(&app, &screenshots, &item.id, &title) {
            Ok(renamed) => record_ok(format!("{} “{}”", tr("Renamed to"), renamed.name)),
            Err(err) => record_failure(Failure::other(format!("{}: {err}", tr("Could not rename")))),
        }
    });
}
