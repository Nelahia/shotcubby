use crate::services::i18n::tr;
use super::folder_preferences;
use crate::models::ScreenshotItem;
use std::path::{Path, PathBuf};

const IMAGE_EXTENSIONS: &[&str] = &["png", "jpg", "jpeg", "tiff"];
/// Windows reserves more characters in filenames than macOS does.
const INVALID_NAME_CHARS: &[char] = &['\\', '/', ':', '*', '?', '"', '<', '>', '|'];

/// The vault: wherever the user moved it, else `Documents\ShotCubby`.
pub fn vault_dir() -> PathBuf {
    folder_preferences::custom_vault().unwrap_or_else(default_vault_dir)
}

/// `Documents\ShotCubby` — the Known Folder, so a OneDrive-redirected
/// Documents is resolved too.
pub fn default_vault_dir() -> PathBuf {
    dirs::document_dir()
        .or_else(|| dirs::home_dir().map(|home| home.join("Documents")))
        .unwrap_or_else(std::env::temp_dir)
        .join("ShotCubby")
}

/// Where the vault lived before it moved into Documents.
fn legacy_vault_dir() -> Option<PathBuf> {
    dirs::home_dir().map(|home| home.join("ShotCubby"))
}

/// Creates the vault, first moving the old `~\ShotCubby` there wholesale —
/// only when the new vault doesn't exist yet, never merging into one.
pub fn ensure_vault_exists() {
    let vault = vault_dir();
    if !vault.exists() && vault == default_vault_dir() {
        if let Some(legacy) = legacy_vault_dir().filter(|legacy| legacy.is_dir()) {
            if std::fs::rename(&legacy, &vault).is_ok() {
                return;
            }
        }
    }
    let _ = std::fs::create_dir_all(vault);
}

/// Moves a capture into the vault. A plain rename is enough locally; a
/// cross-drive source (e.g. a custom folder on another volume) can make the
/// rename fail, so fall back to copy + recycle-original rather than losing
/// the capture. Mirrors `ScreenshotStorage.moveToVault`.
pub fn move_to_vault(source: &Path) -> Option<PathBuf> {
    let destination = unique_destination(
        &vault_dir(),
        &file_stem(source),
        &extension(source),
    );

    if std::fs::rename(source, &destination).is_ok() {
        return Some(destination);
    }

    if std::fs::copy(source, &destination).is_ok() {
        let _ = trash::delete(source);
        return Some(destination);
    }

    None
}

/// Every screenshot in the vault: today's at its root, plus those filed
/// into the `YYYY-MM-DD` folders (see `day_archive`).
pub fn load_all() -> Vec<ScreenshotItem> {
    let root = vault_dir();
    let day_folders = children(&root).into_iter().filter(|p| is_day_folder(p));

    let mut items: Vec<ScreenshotItem> = std::iter::once(root.clone())
        .chain(day_folders)
        .flat_map(|dir| children(&dir))
        .filter(|path| is_image_file(path))
        .map(ScreenshotItem::from_path)
        .collect();

    items.sort_by(|a, b| b.created_at.cmp(&a.created_at));
    items
}

/// Always Recycle Bin, never a permanent delete.
pub fn delete(path: &Path) -> bool {
    trash::delete(path).is_ok()
}

/// A fresh capture is often still held open for a moment by Defender, the
/// search indexer or the app that took it; Windows then refuses the rename
/// (sharing violation) although it works a second later.
const RENAME_ATTEMPTS: u32 = 6;
const RENAME_RETRY_DELAY: std::time::Duration = std::time::Duration::from_millis(250);

/// Renames a screenshot already in the vault, keeping its extension and
/// enforcing name uniqueness. Returns the new path, or why it failed.
pub fn rename(path: &Path, new_name: &str) -> Result<PathBuf, String> {
    let sanitized = sanitize(new_name);
    if sanitized.is_empty() {
        return Err(tr("That name is empty or only has characters Windows does not allow"));
    }
    if sanitized == file_stem(path) {
        return Ok(path.to_path_buf());
    }

    let parent = path.parent().ok_or_else(|| tr("The file has no folder"))?;
    let ext = extension(path);
    for attempt in 1..=RENAME_ATTEMPTS {
        let destination = unique_destination(parent, &sanitized, &ext);
        match std::fs::rename(path, &destination) {
            Ok(()) => return Ok(destination),
            Err(err) if attempt == RENAME_ATTEMPTS => return Err(err.to_string()),
            Err(_) => std::thread::sleep(RENAME_RETRY_DELAY),
        }
    }
    unreachable!("the last attempt returns")
}

pub(super) fn children(dir: &Path) -> Vec<PathBuf> {
    std::fs::read_dir(dir)
        .map(|entries| entries.filter_map(|e| e.ok()).map(|e| e.path()).collect())
        .unwrap_or_default()
}

/// Name of the folder a past day's screenshots are filed into.
pub(super) const DAY_FOLDER_FORMAT: &str = "%Y-%m-%d";

fn is_day_folder(path: &Path) -> bool {
    path.is_dir()
        && path
            .file_name()
            .and_then(|n| n.to_str())
            .is_some_and(|n| chrono::NaiveDate::parse_from_str(n, DAY_FOLDER_FORMAT).is_ok())
}

pub(super) fn sanitize(name: &str) -> String {
    name.trim()
        .chars()
        .filter(|c| !INVALID_NAME_CHARS.contains(c))
        .collect()
}

pub(super) fn unique_destination(dir: &Path, base_name: &str, ext: &str) -> PathBuf {
    let mut destination = dir.join(format!("{base_name}.{ext}"));
    let mut counter = 1;
    while destination.exists() {
        destination = dir.join(format!("{base_name}_{counter}.{ext}"));
        counter += 1;
    }
    destination
}

pub(super) fn file_stem(path: &Path) -> String {
    path.file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default()
}

pub(super) fn extension(path: &Path) -> String {
    path.extension()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default()
}

pub(super) fn is_image_file(path: &Path) -> bool {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|e| IMAGE_EXTENSIONS.contains(&e.to_lowercase().as_str()))
        .unwrap_or(false)
}
