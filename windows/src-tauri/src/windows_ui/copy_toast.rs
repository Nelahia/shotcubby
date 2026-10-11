use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use tauri::{AppHandle, Emitter, Manager, PhysicalPosition, WebviewUrl, WebviewWindow, WebviewWindowBuilder};

use super::COPY_TOAST_LABEL;

const COPY_TOAST_SIZE: (f64, f64) = (180.0, 56.0);
const COPY_TOAST_MARGIN: f64 = 24.0;
const COPY_TOAST_DURATION: Duration = Duration::from_millis(1300);

static GENERATION: AtomicU64 = AtomicU64::new(0);

/// Returns the "Copied" confirmation toast window, creating it (hidden) on
/// first use.
pub fn ensure_copy_toast(app: &AppHandle) -> WebviewWindow {
    if let Some(window) = app.get_webview_window(COPY_TOAST_LABEL) {
        return window;
    }

    let window = WebviewWindowBuilder::new(app, COPY_TOAST_LABEL, WebviewUrl::App("copy-toast.html".into()))
        .inner_size(COPY_TOAST_SIZE.0, COPY_TOAST_SIZE.1)
        .resizable(false)
        .decorations(false)
        .always_on_top(true)
        .skip_taskbar(true)
        .visible(false)
        .shadow(true)
        .transparent(true)
        .focused(false)
        .build()
        .expect("failed to build copy-toast window");

    window
}

/// Shows a small "Copied" confirmation centered near the top of the monitor
/// under the cursor, auto-dismissing it shortly after. Mirrors `show_toast`:
/// a newer copy arriving before the dismiss just restarts the timer
/// (generation counter) instead of stacking dismiss threads.
pub fn show_copy_toast(app: &AppHandle) {
    let window = ensure_copy_toast(app);

    let monitor = app
        .cursor_position()
        .ok()
        .and_then(|pos| app.monitor_from_point(pos.x, pos.y).ok().flatten())
        .or_else(|| app.primary_monitor().ok().flatten());

    if let Some(monitor) = monitor {
        let area = monitor.work_area();
        let x = area.position.x as f64 + (area.size.width as f64 - COPY_TOAST_SIZE.0) / 2.0;
        let y = area.position.y as f64 + COPY_TOAST_MARGIN;
        let _ = window.set_position(PhysicalPosition::new(x, y));
    }

    let _ = window.emit_to(COPY_TOAST_LABEL, "copy-toast-show", ());
    let _ = window.show();

    let generation = GENERATION.fetch_add(1, Ordering::SeqCst) + 1;
    let window_for_dismiss = window.clone();
    std::thread::spawn(move || {
        std::thread::sleep(COPY_TOAST_DURATION);
        if GENERATION.load(Ordering::SeqCst) == generation {
            let _ = window_for_dismiss.hide();
        }
    });
}
