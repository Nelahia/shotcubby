use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};

use drag::{DragItem, DragResult, Image, Options};
use tauri::WebviewWindow;

use super::thumbnails;

const PREVIEW_PX: u32 = 112;

static DRAGGING: AtomicBool = AtomicBool::new(false);

/// True while a screenshot is being dragged out of a window. The popover and the
/// Spotlight close on losing focus, and a drag must not close them.
pub fn is_dragging() -> bool {
    DRAGGING.load(Ordering::SeqCst)
}

/// Whether the screen point (physical pixels) is inside `window`.
fn over_window(window: &WebviewWindow, x: i32, y: i32) -> bool {
    let (Ok(origin), Ok(size)) = (window.outer_position(), window.outer_size()) else {
        return false;
    };
    x >= origin.x && x < origin.x + size.width as i32 && y >= origin.y && y < origin.y + size.height as i32
}

/// Starts a native drag of the file out of `window`: it can be dropped on the
/// desktop, in Explorer or in any app that takes files, and is copied there.
/// The window closes once the file has been dropped elsewhere; Esc, or a drop
/// back on the window itself, cancels and keeps it.
/// The drag loop blocks its thread and needs the UI one, so it runs there.
pub fn start(window: &WebviewWindow, path: PathBuf) -> Result<(), String> {
    let preview = match thumbnails::png_bytes(&path, PREVIEW_PX) {
        Some(bytes) => Image::Raw(bytes),
        None => Image::File(path.clone()),
    };
    if DRAGGING.swap(true, Ordering::SeqCst) {
        return Ok(());
    }

    let dragged = window.clone();
    window
        .run_on_main_thread(move || {
            let closing = dragged.clone();
            let started = drag::start_drag(
                &dragged,
                DragItem::Files(vec![path]),
                preview,
                move |result, cursor| {
                    // Put back on its own window, the screenshot goes nowhere: it
                    // counts as a cancel and the window stays open.
                    if matches!(result, DragResult::Dropped) && !over_window(&closing, cursor.x, cursor.y) {
                        let _ = closing.hide();
                    }
                },
                Options::default(),
            );
            DRAGGING.store(false, Ordering::SeqCst);
            if let Err(error) = started {
                eprintln!("file drag failed: {error}");
            }
        })
        .map_err(|e| e.to_string())
}
