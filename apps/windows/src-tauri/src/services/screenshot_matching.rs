use std::path::{Path, PathBuf};

use super::folder_preferences;
use super::screenshot_watcher::AccessFailure;

pub fn list_file_names(dir: &Path) -> Vec<String> {
    std::fs::read_dir(dir)
        .map(|entries| {
            entries
                .filter_map(|e| e.ok())
                .filter_map(|e| e.file_name().into_string().ok())
                .collect()
        })
        .unwrap_or_default()
}

pub fn access_failure(dir: &Path, is_default_location: bool) -> Option<AccessFailure> {
    if std::fs::read_dir(dir).is_ok() {
        return None;
    }

    if !dir.exists() {
        // The default location (Pictures\Screenshots) may simply not exist
        // yet on a fresh machine — create it rather than surfacing an error.
        // A missing *custom* folder is a real failure: the user picked it.
        if is_default_location && std::fs::create_dir_all(dir).is_ok() {
            return None;
        }
        return Some(AccessFailure::Missing);
    }

    Some(AccessFailure::AccessDenied)
}

pub fn is_screenshot_file(path: &Path) -> bool {
    let Some(ext) = path.extension().and_then(|e| e.to_str()) else {
        return false;
    };
    if !["png", "jpg", "jpeg", "tiff"].contains(&ext.to_lowercase().as_str()) {
        return false;
    }

    let name = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or_default()
        .to_lowercase()
        .replace('\u{2019}', "'");

    name.contains("screenshot") || name.contains("capture d'écran") || name.contains("capture d'ecran")
}

/// Default screenshot directory on Windows: `Pictures\Screenshots`, the
/// folder `Win+PrtScn` saves to. `dirs::picture_dir()` resolves a
/// OneDrive-redirected Pictures library on its own.
pub fn resolve_screenshot_directory() -> PathBuf {
    if let Some(custom) = folder_preferences::custom_directory() {
        return custom;
    }
    dirs::picture_dir()
        .unwrap_or_else(|| dirs::home_dir().unwrap_or_else(std::env::temp_dir).join("Pictures"))
        .join("Screenshots")
}
