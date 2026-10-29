use base64::Engine;
use std::collections::HashMap;
use std::io::Cursor;
use std::path::Path;
use std::sync::{Mutex, OnceLock};

/// In-memory thumbnail cache, the Windows analog of `ThumbnailCache` (which
/// wrapped `QuickLookThumbnailing` on macOS). Keyed by path + size since a
/// rename changes the path and simply leaves the old entry unused — fine for
/// a short-lived background utility with a bounded number of screenshots.
fn cache() -> &'static Mutex<HashMap<String, String>> {
    static CACHE: OnceLock<Mutex<HashMap<String, String>>> = OnceLock::new();
    CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Returns a `data:image/png;base64,...` URL sized to fit within
/// `max_px` x `max_px`, or `None` if the file can't be decoded.
pub fn data_url(path: &Path, max_px: u32) -> Option<String> {
    let key = format!("{}#{}", path.display(), max_px);
    if let Some(cached) = cache().lock().unwrap().get(&key) {
        return Some(cached.clone());
    }

    let encoded = base64::engine::general_purpose::STANDARD.encode(png_bytes(path, max_px)?);
    let data_url = format!("data:image/png;base64,{encoded}");
    cache().lock().unwrap().insert(key, data_url.clone());
    Some(data_url)
}

/// PNG bytes of the image fitted within `max_px` x `max_px` (also the preview
/// that follows the cursor during a drag), or `None` if it can't be decoded.
pub fn png_bytes(path: &Path, max_px: u32) -> Option<Vec<u8>> {
    let image = image::open(path).ok()?.thumbnail(max_px, max_px);
    let mut bytes: Vec<u8> = Vec::new();
    image
        .write_to(&mut Cursor::new(&mut bytes), image::ImageFormat::Png)
        .ok()?;
    Some(bytes)
}
