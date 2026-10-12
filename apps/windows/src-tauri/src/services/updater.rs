use std::sync::Mutex;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use serde::Serialize;
use tauri::AppHandle;
use tauri_plugin_updater::UpdaterExt;

use super::update_preferences;

const FIRST_CHECK_DELAY: Duration = Duration::from_secs(10);
const CHECK_INTERVAL: Duration = Duration::from_secs(6 * 60 * 60);

/// What Settings shows. `state` is one of `unknown` (nothing checked yet),
/// `checking`, `up_to_date`, `installing` (`detail` = version) or `error`
/// (`detail` = message). `checked_at` is a Unix time in milliseconds.
#[derive(Clone, Serialize)]
pub struct UpdateStatus {
    pub state: String,
    pub detail: Option<String>,
    pub checked_at: Option<u64>,
}

static STATUS: Mutex<UpdateStatus> = Mutex::new(UpdateStatus {
    state: String::new(),
    detail: None,
    checked_at: None,
});

pub fn status() -> UpdateStatus {
    let mut status = STATUS.lock().unwrap_or_else(|e| e.into_inner()).clone();
    if status.state.is_empty() {
        status.state = "unknown".into();
    }
    status
}

fn set(state: &str, detail: Option<String>, stamp: bool) {
    let mut status = STATUS.lock().unwrap_or_else(|e| e.into_inner());
    status.state = state.into();
    status.detail = detail;
    if stamp {
        status.checked_at = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .ok()
            .map(|d| d.as_millis() as u64);
    }
}

/// Checks for a new release shortly after launch, then every few hours (a
/// tray app can run for days). The only network request ShotCubby makes:
/// a read of `latest.json` on the project's GitHub releases. The setting is
/// re-read each round, so switching updates off in Settings applies at once.
pub fn start(app: AppHandle) {
    std::thread::spawn(move || {
        std::thread::sleep(FIRST_CHECK_DELAY);
        loop {
            if update_preferences::enabled() {
                tauri::async_runtime::block_on(check_and_install(&app));
            }
            std::thread::sleep(CHECK_INTERVAL);
        }
    });
}

/// Runs one check, installing and restarting into a newer release if there
/// is one. Also the "Check now" action, which works even with automatic
/// updates off. A check already in flight is not started twice.
pub async fn check_and_install(app: &AppHandle) -> UpdateStatus {
    if status().state == "checking" {
        return status();
    }
    set("checking", None, false);
    match install_if_available(app).await {
        Ok(()) => set("up_to_date", None, true),
        Err(err) => {
            eprintln!("Update check failed: {err}");
            set("error", Some(err.to_string()), true);
        }
    }
    status()
}

/// Downloads and installs a newer signed release, then restarts into it.
/// The updater verifies the download against the public key baked into
/// `tauri.conf.json`, so only releases signed by the maintainer install.
async fn install_if_available(app: &AppHandle) -> tauri_plugin_updater::Result<()> {
    let Some(update) = app.updater()?.check().await? else {
        return Ok(());
    };
    set("installing", Some(update.version.clone()), false);
    update.download_and_install(|_, _| {}, || {}).await?;
    app.restart();
}
