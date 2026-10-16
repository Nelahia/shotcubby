use std::io::Cursor;
use std::path::Path;

/// Longest side sent to a provider: enough to read UI text, small enough to
/// keep the upload light and cheap.
const MAX_SIDE: u32 = 1024;

/// Decodes a screenshot and returns it downscaled as JPEG bytes.
pub fn prepare_jpeg(path: &Path) -> Option<Vec<u8>> {
    let image = image::open(path).ok()?.thumbnail(MAX_SIDE, MAX_SIDE);
    encode(image)
}

/// A tiny generated picture, for testing a key without touching a real capture.
pub fn sample_jpeg() -> Option<Vec<u8>> {
    encode(image::DynamicImage::new_rgb8(96, 96))
}

fn encode(image: image::DynamicImage) -> Option<Vec<u8>> {
    let mut bytes = Vec::new();
    // JPEG has no alpha channel.
    image::DynamicImage::ImageRgb8(image.to_rgb8())
        .write_to(&mut Cursor::new(&mut bytes), image::ImageFormat::Jpeg)
        .ok()?;
    Some(bytes)
}
