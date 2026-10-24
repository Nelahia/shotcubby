use chrono::Local;
use std::borrow::Cow;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::Arc;
use std::time::Duration;

use super::storage;

type NewImageCallback = Arc<dyn Fn(PathBuf) + Send + Sync>;

/// Polls the Windows clipboard sequence number every 0.8s — the exact
/// analog of `NSPasteboard.changeCount` polling in `ClipboardWatcher.swift`.
pub struct ClipboardWatcher {
    last_sequence: Arc<AtomicU32>,
    paused: Arc<AtomicBool>,
    on_new_image: NewImageCallback,
}

impl ClipboardWatcher {
    pub fn new(on_new_image: impl Fn(PathBuf) + Send + Sync + 'static) -> Self {
        ClipboardWatcher {
            last_sequence: Arc::new(AtomicU32::new(current_sequence())),
            paused: Arc::new(AtomicBool::new(false)),
            on_new_image: Arc::new(on_new_image),
        }
    }

    /// Call right after this process writes to the clipboard itself (the
    /// Copy action), so that write isn't mistaken for a new capture.
    pub fn pause_temporarily(&self) {
        self.paused.store(true, Ordering::SeqCst);
        let paused = self.paused.clone();
        let last_sequence = self.last_sequence.clone();
        std::thread::spawn(move || {
            std::thread::sleep(Duration::from_millis(1500));
            last_sequence.store(current_sequence(), Ordering::SeqCst);
            paused.store(false, Ordering::SeqCst);
        });
    }

    pub fn start_watching(&self) {
        let last_sequence = self.last_sequence.clone();
        let paused = self.paused.clone();
        let on_new_image = self.on_new_image.clone();

        std::thread::spawn(move || {
            let mut clipboard = match arboard::Clipboard::new() {
                Ok(c) => c,
                Err(_) => return,
            };

            loop {
                std::thread::sleep(Duration::from_millis(800));
                if paused.load(Ordering::SeqCst) {
                    continue;
                }

                let current = current_sequence();
                if current == last_sequence.load(Ordering::SeqCst) {
                    continue;
                }
                last_sequence.store(current, Ordering::SeqCst);

                // Reading the clipboard locks it for every other app while it is
                // open, and makes a source app that renders lazily produce its
                // data. Only do that when an image is actually there: a plain
                // text copy must never be touched, or pasting it can fail.
                if !clipboard_has_image() {
                    continue;
                }

                if let Some(path) = try_save_clipboard_image(&mut clipboard) {
                    on_new_image(path);
                }
            }
        });
    }

    /// Writes a vault image to the clipboard (the Copy action), pausing the
    /// watcher first so this write isn't mistaken for a new capture.
    pub fn copy_image_to_clipboard(&self, path: &Path) -> Result<(), String> {
        let image = image::open(path).map_err(|e| e.to_string())?.to_rgba8();
        let width = image.width() as usize;
        let height = image.height() as usize;
        let bytes = image.into_raw();

        self.pause_temporarily();

        let mut clipboard = arboard::Clipboard::new().map_err(|e| e.to_string())?;
        clipboard
            .set_image(arboard::ImageData {
                width,
                height,
                bytes: Cow::Owned(bytes),
            })
            .map_err(|e| e.to_string())
    }
}

/// CF_BITMAP, CF_DIB or CF_DIBV5 on the clipboard. Asking opens nothing, so it
/// is safe to do on every change.
fn clipboard_has_image() -> bool {
    const IMAGE_FORMATS: [u32; 3] = [2, 8, 17];
    IMAGE_FORMATS
        .iter()
        .any(|&format| unsafe { windows::Win32::System::DataExchange::IsClipboardFormatAvailable(format).is_ok() })
}

fn current_sequence() -> u32 {
    unsafe { windows::Win32::System::DataExchange::GetClipboardSequenceNumber() }
}

fn try_save_clipboard_image(clipboard: &mut arboard::Clipboard) -> Option<PathBuf> {
    let image_data = clipboard.get_image().ok()?;
    let width = u32::try_from(image_data.width).ok()?;
    let height = u32::try_from(image_data.height).ok()?;
    let buffer = image::RgbaImage::from_raw(width, height, image_data.bytes.into_owned())?;

    // Literal "at" needs no escaping in chrono's format syntax (unlike the
    // quoted 'at' in Swift's ICU-style DateFormatter) — plain text passes
    // through as-is.
    let timestamp = Local::now().format("%Y-%m-%d at %H.%M.%S");
    let vault = storage::vault_dir();
    // Two copies within one second must not share a file: the second would
    // overwrite the first and leave two list entries for a single path. The
    // counter goes before the tag, which has to stay the end of the name.
    let mut destination = vault.join(format!("Screenshot {timestamp} (clipboard).png"));
    let mut counter = 1;
    while destination.exists() {
        destination = vault.join(format!("Screenshot {timestamp}_{counter} (clipboard).png"));
        counter += 1;
    }

    buffer.save(&destination).ok()?;
    Some(destination)
}
