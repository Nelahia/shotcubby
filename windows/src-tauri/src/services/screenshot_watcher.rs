use notify::{RecommendedWatcher, RecursiveMode, Watcher};
use serde::Serialize;
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::channel;
use std::sync::Arc;
use std::time::Duration;

use super::folder_preferences;
use super::screenshot_matching::{access_failure, is_screenshot_file, list_file_names, resolve_screenshot_directory};

/// Why the screenshot folder can't be read. Simpler than macOS's TCC-era
/// cases (no cloud-provider distinction needed — `dirs::picture_dir()`
/// already resolves a OneDrive-redirected Pictures folder on its own).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum AccessFailure {
    /// A custom folder was deleted, or a volume unmounted.
    Missing,
    /// E.g. Controlled Folder Access is blocking writes to this folder.
    AccessDenied,
}

type NewScreenshotCallback = Arc<dyn Fn(PathBuf) + Send + Sync>;
type AccessFailedCallback = Arc<dyn Fn(AccessFailure) + Send + Sync>;

pub struct ScreenshotWatcher {
    dir: PathBuf,
    generation: Arc<AtomicU64>,
    on_new_screenshot: NewScreenshotCallback,
    on_access_failed: AccessFailedCallback,
}

impl ScreenshotWatcher {
    pub fn new(
        on_new_screenshot: impl Fn(PathBuf) + Send + Sync + 'static,
        on_access_failed: impl Fn(AccessFailure) + Send + Sync + 'static,
    ) -> Self {
        ScreenshotWatcher {
            dir: resolve_screenshot_directory(),
            generation: Arc::new(AtomicU64::new(0)),
            on_new_screenshot: Arc::new(on_new_screenshot),
            on_access_failed: Arc::new(on_access_failed),
        }
    }

    pub fn screenshot_dir(&self) -> &Path {
        &self.dir
    }

    /// Re-resolves the screenshot directory (picks up a newly chosen custom
    /// folder) and restarts watching from scratch.
    pub fn restart(&mut self) {
        self.dir = resolve_screenshot_directory();
        self.start_watching();
    }

    /// Invalidates any previously running watch loop (it notices within one
    /// `recv_timeout` tick) and starts a fresh one on the current `dir`.
    pub fn start_watching(&self) {
        let my_generation = self.generation.fetch_add(1, Ordering::SeqCst) + 1;
        let generation = self.generation.clone();
        let dir = self.dir.clone();
        let is_default_location = folder_preferences::custom_directory().is_none();
        let on_new = self.on_new_screenshot.clone();
        let on_failed = self.on_access_failed.clone();

        std::thread::spawn(move || {
            run_watch_loop(dir, is_default_location, my_generation, generation, on_new, on_failed);
        });
    }
}

fn run_watch_loop(
    dir: PathBuf,
    is_default_location: bool,
    my_generation: u64,
    generation: Arc<AtomicU64>,
    on_new: NewScreenshotCallback,
    on_failed: AccessFailedCallback,
) {
    if let Some(failure) = access_failure(&dir, is_default_location) {
        on_failed(failure);
        return;
    }

    let mut known_files: HashSet<String> = list_file_names(&dir).into_iter().collect();

    let (tx, rx) = channel::<notify::Result<notify::Event>>();
    let mut watcher = match RecommendedWatcher::new(tx, notify::Config::default()) {
        Ok(w) => w,
        Err(_) => return,
    };
    if watcher.watch(&dir, RecursiveMode::NonRecursive).is_err() {
        return;
    }

    loop {
        if generation.load(Ordering::SeqCst) != my_generation {
            return;
        }

        // `recv_timeout` doubles as the FS-event path and the 10s polling
        // fallback (a provider/sync quirk can materialize a file without a
        // raw event ever firing) — one loop covers both, unlike the two
        // separate mechanisms the Mac version needed.
        match rx.recv_timeout(Duration::from_secs(10)) {
            Ok(Ok(_event)) => {}
            Ok(Err(_)) => {}
            Err(_) => {} // timeout: fall through and rescan anyway
        }

        for name in list_file_names(&dir) {
            if known_files.contains(&name) {
                continue;
            }
            known_files.insert(name.clone());

            let path = dir.join(&name);
            if is_screenshot_file(&path) {
                let on_new = on_new.clone();
                let generation = generation.clone();
                std::thread::spawn(move || {
                    if generation.load(Ordering::SeqCst) == my_generation {
                        announce_when_stable(&path, on_new);
                    }
                });
            }
        }
    }
}

/// A capture is announced only once its size stops changing — the OS can
/// write the file in place, and a provider-backed folder can surface a
/// zero-byte placeholder first.
fn announce_when_stable(path: &Path, on_new: NewScreenshotCallback) {
    const MAX_ATTEMPTS: u32 = 20; // 20 x 0.5s = 10s, then give up
    let mut last_size: Option<u64> = None;

    for _ in 0..MAX_ATTEMPTS {
        let size = std::fs::metadata(path).map(|m| m.len()).unwrap_or(0);
        if size > 0 && last_size == Some(size) {
            on_new(path.to_path_buf());
            return;
        }
        last_size = Some(size);
        std::thread::sleep(Duration::from_millis(500));
    }
}
