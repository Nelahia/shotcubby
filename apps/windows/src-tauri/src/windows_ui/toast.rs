use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use tauri::{AppHandle, Emitter, Manager, PhysicalPosition, WebviewUrl, WebviewWindow, WebviewWindowBuilder};

use super::TOAST_LABEL;
use crate::models::ScreenshotItem;

const TOAST_SIZE: (f64, f64) = (160.0, 160.0);
const TOAST_MARGIN: f64 = 24.0;
const TOAST_DURATION: Duration = Duration::from_secs(4);

static GENERATION: AtomicU64 = AtomicU64::new(0);

/// Returns the capture toast window, creating it (hidden) on first use.
pub fn ensure_toast(app: &AppHandle) -> WebviewWindow {
    if let Some(window) = app.get_webview_window(TOAST_LABEL) {
        return window;
    }

    let window = WebviewWindowBuilder::new(app, TOAST_LABEL, WebviewUrl::App("toast.html".into()))
        .inner_size(TOAST_SIZE.0, TOAST_SIZE.1)
        .resizable(false)
        .decorations(false)
        .always_on_top(true)
        .skip_taskbar(true)
        .visible(false)
        // The native shadow on a borderless window makes Windows 11 draw its own
        // rounded frame and border around the (already rounded, transparent) page.
        .shadow(false)
        .transparent(true)
        .focused(false)
        .build()
        .expect("failed to build toast window");

    window
}

/// Shows a thumbnail of `item` near the bottom-right of the monitor under
/// the cursor, auto-dismissing it after a few seconds. Mirrors macOS's
/// screenshot preview thumbnail. A newer capture arriving before the
/// dismiss just restarts the timer (generation counter) instead of
/// stacking dismiss threads.
pub fn show_toast(app: &AppHandle, item: &ScreenshotItem) {
    let window = ensure_toast(app);

    let monitor = app
        .cursor_position()
        .ok()
        .and_then(|pos| app.monitor_from_point(pos.x, pos.y).ok().flatten())
        .or_else(|| app.primary_monitor().ok().flatten());

    if let Some(monitor) = monitor {
        let area = monitor.work_area();
        let x = area.position.x as f64 + area.size.width as f64 - TOAST_SIZE.0 - TOAST_MARGIN;
        let y = area.position.y as f64 + area.size.height as f64 - TOAST_SIZE.1 - TOAST_MARGIN;
        let _ = window.set_position(PhysicalPosition::new(x, y));
    }

    let _ = window.emit_to(TOAST_LABEL, "toast-show", item);
    let _ = window.show();

    let generation = GENERATION.fetch_add(1, Ordering::SeqCst) + 1;
    let window_for_dismiss = window.clone();
    std::thread::spawn(move || {
        std::thread::sleep(TOAST_DURATION);
        if GENERATION.load(Ordering::SeqCst) == generation {
            let _ = window_for_dismiss.hide();
        }
    });
}
