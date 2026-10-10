use crate::models::ScreenshotItem;
use std::path::{Path, PathBuf};

const IMAGE_EXTENSIONS: &[&str] = &["png", "jpg", "jpeg", "tiff"];
/// Windows reserves more characters in filenames than macOS does.
const INVALID_NAME_CHARS: &[char] = &['\\', '/', ':', '*', '?', '"', '<', '>', '|'];

pub fn vault_dir() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(std::env::temp_dir)
        .join("ShotCubby")
}

pub fn ensure_vault_exists() {
    let _ = std::fs::create_dir_all(vault_dir());
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

pub fn load_all() -> Vec<ScreenshotItem> {
    let Ok(entries) = std::fs::read_dir(vault_dir()) else {
        return Vec::new();
    };

    let mut items: Vec<ScreenshotItem> = entries
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
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

/// Renames a screenshot already in the vault, keeping its extension and
/// enforcing name uniqueness. Returns the new path, or `None` if the name is
/// empty or the move fails.
pub fn rename(path: &Path, new_name: &str) -> Option<PathBuf> {
    let sanitized = sanitize(new_name);
    if sanitized.is_empty() {
        return None;
    }
    if sanitized == file_stem(path) {
        return Some(path.to_path_buf());
    }

    let parent = path.parent()?;
    let destination = unique_destination(parent, &sanitized, &extension(path));
    std::fs::rename(path, &destination).ok().map(|_| destination)
}

fn sanitize(name: &str) -> String {
    name.trim()
        .chars()
        .filter(|c| !INVALID_NAME_CHARS.contains(c))
        .collect()
}

fn unique_destination(dir: &Path, base_name: &str, ext: &str) -> PathBuf {
    let mut destination = dir.join(format!("{base_name}.{ext}"));
    let mut counter = 1;
    while destination.exists() {
        destination = dir.join(format!("{base_name}_{counter}.{ext}"));
        counter += 1;
    }
    destination
}

fn file_stem(path: &Path) -> String {
    path.file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn extension(path: &Path) -> String {
    path.extension()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn is_image_file(path: &Path) -> bool {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|e| IMAGE_EXTENSIONS.contains(&e.to_lowercase().as_str()))
        .unwrap_or(false)
}
