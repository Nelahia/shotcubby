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

/// Starts a native drag of the file out of `window`: it can be dropped on the
/// desktop, in Explorer or in any app that takes files, and is copied there.
/// The window closes once the file has been dropped; Esc cancels and keeps it.
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
            // The preview that follows the cursor is a window of its own, and it
            // would pass under this always-on-top one: hidden while over it.
            let on_top = dragged.is_always_on_top().unwrap_or(false);
            let _ = dragged.set_always_on_top(false);
            let started = drag::start_drag(
                &dragged,
                DragItem::Files(vec![path]),
                preview,
                move |result, _| {
                    if matches!(result, DragResult::Dropped) {
                        let _ = closing.hide();
                    }
                },
                Options::default(),
            );
            DRAGGING.store(false, Ordering::SeqCst);
            let _ = dragged.set_always_on_top(on_top);
            if let Err(error) = started {
                eprintln!("file drag failed: {error}");
            }
        })
        .map_err(|e| e.to_string())
}
