use tauri::{AppHandle, Emitter, Manager, PhysicalPosition, WebviewUrl, WebviewWindow, WebviewWindowBuilder};

use super::{hide_on_blur, SPOTLIGHT_LABEL};

const SPOTLIGHT_SIZE: (f64, f64) = (720.0, 460.0);

/// Returns the Spotlight-style search panel, creating it (hidden) on first
/// use. Mirrors `SpotlightController`'s `NSPanel`.
pub fn ensure_spotlight(app: &AppHandle) -> WebviewWindow {
    if let Some(window) = app.get_webview_window(SPOTLIGHT_LABEL) {
        return window;
    }

    let window = WebviewWindowBuilder::new(app, SPOTLIGHT_LABEL, WebviewUrl::App("spotlight.html".into()))
        .title("ShotCubby Search")
        .inner_size(SPOTLIGHT_SIZE.0, SPOTLIGHT_SIZE.1)
        .resizable(false)
        .decorations(false)
        .always_on_top(true)
        .skip_taskbar(true)
        .visible(false)
        .shadow(true)
        .transparent(true)
        .build()
        .expect("failed to build spotlight window");

    hide_on_blur(&window);
    window
}

/// Toggles the Spotlight panel, centered on the monitor under the cursor —
/// the same placement `SpotlightController.show()` uses on macOS.
pub fn toggle_spotlight(app: &AppHandle) {
    let window = ensure_spotlight(app);
    if window.is_visible().unwrap_or(false) {
        let _ = window.hide();
        return;
    }

    if let Ok(cursor) = app.cursor_position() {
        let monitor = app
            .monitor_from_point(cursor.x, cursor.y)
            .ok()
            .flatten()
            .or_else(|| app.primary_monitor().ok().flatten());

        if let Some(monitor) = monitor {
            // Physical work area vs logical window size: scale before centring.
            let scale = monitor.scale_factor();
            let area = monitor.work_area();
            let x = area.position.x as f64 + (area.size.width as f64 - SPOTLIGHT_SIZE.0 * scale) / 2.0;
            let y = area.position.y as f64 + (area.size.height as f64 - SPOTLIGHT_SIZE.1 * scale) / 2.0;
            let _ = window.set_position(PhysicalPosition::new(x, y));
        }
    }

    let _ = window.show();
    let _ = window.set_focus();
    let _ = app.emit_to(SPOTLIGHT_LABEL, "spotlight-shown", ());
}
