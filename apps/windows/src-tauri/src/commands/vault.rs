use std::path::PathBuf;
use tauri::{AppHandle, Emitter, Manager};

use crate::app_state::AppStateInner;
use crate::services::{storage, vault_move};
use crate::services::vault_move::VaultInfo;

#[tauri::command]
pub fn get_vault_info() -> VaultInfo {
    vault_move::info()
}

/// Asks where to move the vault; returns the resulting vault path, or `None`
/// if the dialog was dismissed. Nothing moves until `move_vault`.
#[tauri::command]
pub fn choose_vault_folder() -> Option<String> {
    let chosen = rfd::FileDialog::new()
        .set_title("Choose where ShotCubby keeps your screenshots")
        .pick_folder()?;
    Some(vault_move::target_for(&chosen).display().to_string())
}

#[tauri::command]
pub async fn move_vault(app: AppHandle, target: String) -> Result<(), String> {
    let target = PathBuf::from(target);
    tauri::async_runtime::spawn_blocking(move || vault_move::move_vault(&target))
        .await
        .map_err(|e| e.to_string())??;

    let state = app.state::<AppStateInner>();
    *state.screenshots.lock().unwrap() = storage::load_all();
    let _ = app.emit("screenshots-reloaded", ());
    Ok(())
}
