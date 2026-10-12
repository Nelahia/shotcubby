use serde::Serialize;
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Source {
    File,
    Clipboard,
}

/// Mirrors `ScreenshotItem.swift`: identity (the full path, unique even when
/// two day folders hold the same file name) and "source" are both derived
/// from the file on disk, not stored separately, so a rename can never
/// desync them from the real file.
#[derive(Debug, Clone, Serialize)]
pub struct ScreenshotItem {
    pub id: String,
    pub path: PathBuf,
    pub name: String,
    /// Milliseconds since epoch, ready for `Date` on the JS side.
    pub created_at: i64,
    pub source: Source,
}

impl ScreenshotItem {
    pub fn from_path(path: PathBuf) -> Self {
        let id = path.to_string_lossy().into_owned();
        let name = file_stem(&path);
        let created_at = created_at_millis(&path);
        let source = if name.ends_with("(clipboard)") {
            Source::Clipboard
        } else {
            Source::File
        };

        ScreenshotItem {
            id,
            path,
            name,
            created_at,
            source,
        }
    }
}

fn file_stem(path: &Path) -> String {
    path.file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn created_at_millis(path: &Path) -> i64 {
    std::fs::metadata(path)
        .and_then(|m| m.created().or_else(|_| m.modified()))
        .map(|t| {
            t.duration_since(UNIX_EPOCH)
                .map(|d| d.as_millis() as i64)
                .unwrap_or(0)
        })
        .unwrap_or(0)
}
