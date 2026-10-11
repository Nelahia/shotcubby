use std::time::Duration;

use tauri::AppHandle;
use tauri_plugin_updater::UpdaterExt;

use super::update_preferences;

const FIRST_CHECK_DELAY: Duration = Duration::from_secs(10);
const CHECK_INTERVAL: Duration = Duration::from_secs(6 * 60 * 60);

/// Checks for a new release shortly after launch, then every few hours (a
/// tray app can run for days). The only network request ShotCubby makes:
/// a read of `latest.json` on the project's GitHub releases. The setting is
/// re-read each round, so switching updates off in Settings applies at once.
pub fn start(app: AppHandle) {
    std::thread::spawn(move || {
        std::thread::sleep(FIRST_CHECK_DELAY);
        loop {
            if update_preferences::enabled() {
                if let Err(err) = tauri::async_runtime::block_on(install_if_available(&app)) {
                    eprintln!("Update check failed: {err}");
                }
            }
            std::thread::sleep(CHECK_INTERVAL);
        }
    });
}

/// Downloads and installs a newer signed release, then restarts into it.
/// The updater verifies the download against the public key baked into
/// `tauri.conf.json`, so only releases signed by the maintainer install.
async fn install_if_available(app: &AppHandle) -> tauri_plugin_updater::Result<()> {
    let Some(update) = app.updater()?.check().await? else {
        return Ok(());
    };
    update.download_and_install(|_, _| {}, || {}).await?;
    app.restart();
}
