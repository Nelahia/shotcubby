use serde::Serialize;
use std::path::{Path, PathBuf};

use super::{folder_preferences, storage};

/// Folder the vault always lives in once moved: the user picks where, the
/// app keeps its own named subfolder so it never mixes with other files.
const VAULT_FOLDER_NAME: &str = "ShotCubby";

#[derive(Serialize)]
pub struct VaultInfo {
    path: PathBuf,
    count: usize,
    bytes: u64,
}

pub fn info() -> VaultInfo {
    let items = storage::load_all();
    let bytes = items
        .iter()
        .filter_map(|item| std::fs::metadata(&item.path).ok())
        .map(|meta| meta.len())
        .sum();
    VaultInfo {
        path: storage::vault_dir(),
        count: items.len(),
        bytes,
    }
}

/// The vault path for a folder the user picked: the folder itself when it is
/// already called `ShotCubby`, else a `ShotCubby` folder inside it.
pub fn target_for(chosen: &Path) -> PathBuf {
    if chosen.file_name().is_some_and(|name| name == VAULT_FOLDER_NAME) {
        chosen.to_path_buf()
    } else {
        chosen.join(VAULT_FOLDER_NAME)
    }
}

/// Moves the whole vault to `to` and remembers it. Nothing is removed from
/// the old place unless the new one is complete.
pub fn move_vault(to: &Path) -> Result<(), String> {
    let from = storage::vault_dir();
    if to == from {
        return Err("That is already the current folder.".into());
    }
    if to.starts_with(&from) || from.starts_with(to) {
        return Err("Choose a folder outside the current one.".into());
    }
    if to.exists() && !(to.is_dir() && storage::children(to).is_empty()) {
        return Err("That folder isn't empty.".into());
    }

    if from.exists() {
        transfer(&from, to)?;
    } else {
        std::fs::create_dir_all(to).map_err(|_| "ShotCubby can't write there.".to_string())?;
    }

    let remembered = (to != storage::default_vault_dir()).then(|| to.to_path_buf());
    folder_preferences::set_custom_vault(remembered);
    Ok(())
}

/// A rename is instant on the same drive; anywhere else (another drive, a
/// locked file) fall back to copying the tree, then deleting the original.
fn transfer(from: &Path, to: &Path) -> Result<(), String> {
    if let Some(parent) = to.parent() {
        std::fs::create_dir_all(parent).map_err(|_| "ShotCubby can't write there.".to_string())?;
    }
    let _ = std::fs::remove_dir(to);
    if std::fs::rename(from, to).is_ok() {
        return Ok(());
    }
    if copy_tree(from, to).is_err() {
        let _ = std::fs::remove_dir_all(to);
        return Err("Couldn't copy the screenshots there. Nothing was moved.".into());
    }
    let _ = std::fs::remove_dir_all(from);
    Ok(())
}

fn copy_tree(from: &Path, to: &Path) -> std::io::Result<()> {
    std::fs::create_dir_all(to)?;
    for entry in std::fs::read_dir(from)? {
        let entry = entry?;
        let destination = to.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            copy_tree(&entry.path(), &destination)?;
        } else {
            std::fs::copy(entry.path(), destination)?;
        }
    }
    Ok(())
}
