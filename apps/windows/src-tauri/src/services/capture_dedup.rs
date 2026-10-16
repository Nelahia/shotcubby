use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::{Duration, Instant};

use crate::models::Source;

/// How long a capture is remembered to spot its twin. The Snipping Tool saves
/// a file and also puts the same image on the clipboard; both reach the app.
const WINDOW: Duration = Duration::from_secs(15);

struct Recent {
    fingerprint: u64,
    source: Source,
    path: PathBuf,
    at: Instant,
}

/// Outcome of registering a capture.
#[derive(Debug, PartialEq, Eq)]
pub enum Claim {
    /// First time this image is seen: carry on as usual.
    Fresh,
    /// The same image already arrived through the other channel; this is the
    /// path of that earlier copy, now forgotten.
    TwinOf(PathBuf),
}

/// Pairs the file and clipboard copies of one capture so only one is kept.
pub struct RecentCaptures {
    window: Duration,
    entries: Mutex<Vec<Recent>>,
}

impl Default for RecentCaptures {
    fn default() -> Self {
        RecentCaptures::with_window(WINDOW)
    }
}

impl RecentCaptures {
    pub fn with_window(window: Duration) -> Self {
        RecentCaptures { window, entries: Mutex::new(Vec::new()) }
    }

    /// Registers a capture and runs `handle` with the outcome while the
    /// registry is still locked. The caller adds the capture to the list (or
    /// discards its twin) inside `handle`, so when two threads handle both
    /// copies at once, the second only ever sees the first one finished.
    pub fn with_claim<R>(&self, path: &Path, source: Source, handle: impl FnOnce(Claim) -> R) -> R {
        let fingerprint = fingerprint(path);
        let mut entries = self.entries.lock().unwrap();
        entries.retain(|r| r.at.elapsed() < self.window);

        let twin = fingerprint.and_then(|fingerprint| {
            entries
                .iter()
                .position(|r| r.fingerprint == fingerprint && r.source != source)
        });
        if let Some(index) = twin {
            return handle(Claim::TwinOf(entries.remove(index).path));
        }
        if let Some(fingerprint) = fingerprint {
            entries.push(Recent { fingerprint, source, path: path.to_path_buf(), at: Instant::now() });
        }
        handle(Claim::Fresh)
    }
}

/// Hash of the decoded pixels: the clipboard copy is re-encoded, so comparing
/// the files' bytes would never match.
fn fingerprint(path: &Path) -> Option<u64> {
    let image = image::open(path).ok()?.to_rgba8();
    let mut hasher = DefaultHasher::new();
    image.dimensions().hash(&mut hasher);
    image.as_raw().hash(&mut hasher);
    Some(hasher.finish())
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{ImageFormat, Rgba, RgbaImage};

    fn picture(name: &str, shade: u8, format: ImageFormat) -> PathBuf {
        let extension = if format == ImageFormat::Png { "png" } else { "tiff" };
        let path = std::env::temp_dir().join(format!("shotcubby-dedup-{}-{name}.{extension}", std::process::id()));
        RgbaImage::from_pixel(8, 8, Rgba([shade, 40, 90, 255]))
            .save_with_format(&path, format)
            .unwrap();
        path
    }

    fn claim(recent: &RecentCaptures, path: &Path, source: Source) -> Claim {
        recent.with_claim(path, source, |claim| claim)
    }

    #[test]
    fn the_same_image_from_the_other_channel_is_a_twin() {
        let recent = RecentCaptures::default();
        let file = picture("twin-file", 10, ImageFormat::Png);
        let clipboard = picture("twin-clip", 10, ImageFormat::Png);
        assert_eq!(claim(&recent, &clipboard, Source::Clipboard), Claim::Fresh);
        assert_eq!(claim(&recent, &file, Source::File), Claim::TwinOf(clipboard));
    }

    #[test]
    fn a_re_encoded_copy_still_matches() {
        let recent = RecentCaptures::default();
        let file = picture("enc-file", 20, ImageFormat::Png);
        let clipboard = picture("enc-clip", 20, ImageFormat::Tiff);
        assert_eq!(claim(&recent, &file, Source::File), Claim::Fresh);
        assert_eq!(claim(&recent, &clipboard, Source::Clipboard), Claim::TwinOf(file));
    }

    #[test]
    fn copies_from_the_same_channel_or_other_images_are_not_twins() {
        let recent = RecentCaptures::default();
        let first = picture("same-1", 30, ImageFormat::Png);
        let second = picture("same-2", 30, ImageFormat::Png);
        let other = picture("other", 200, ImageFormat::Png);
        assert_eq!(claim(&recent, &first, Source::File), Claim::Fresh);
        assert_eq!(claim(&recent, &second, Source::File), Claim::Fresh);
        assert_eq!(claim(&recent, &other, Source::Clipboard), Claim::Fresh);
    }

    #[test]
    fn a_pair_is_consumed_so_a_repeat_capture_starts_fresh() {
        let recent = RecentCaptures::default();
        let image = |name| picture(name, 40, ImageFormat::Png);
        assert_eq!(claim(&recent, &image("rep-c1"), Source::Clipboard), Claim::Fresh);
        assert!(matches!(claim(&recent, &image("rep-f1"), Source::File), Claim::TwinOf(_)));
        assert_eq!(claim(&recent, &image("rep-f2"), Source::File), Claim::Fresh);
    }

    #[test]
    fn captures_are_forgotten_once_the_window_has_passed() {
        let recent = RecentCaptures::with_window(Duration::ZERO);
        let file = picture("late-file", 50, ImageFormat::Png);
        let clipboard = picture("late-clip", 50, ImageFormat::Png);
        assert_eq!(claim(&recent, &file, Source::File), Claim::Fresh);
        assert_eq!(claim(&recent, &clipboard, Source::Clipboard), Claim::Fresh);
    }
}
