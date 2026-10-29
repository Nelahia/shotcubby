use tauri::{
    AppHandle, Emitter, Manager, PhysicalPosition, WebviewUrl, WebviewWindow, WebviewWindowBuilder, WindowEvent,
};

use super::{capture_overlay, SPOTLIGHT_LABEL};
use crate::services::file_drag;

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
        // The native shadow on a borderless window makes Windows 11 draw its own
        // rounded frame and border around the (already rounded, transparent) page.
        .shadow(false)
        .transparent(true)
        // Tauri's own drop target would sit over the page and never draw the
        // picture that follows the cursor during a drag out of this window.
        .disable_drag_drop_handler()
        .build()
        .expect("failed to build spotlight window");

    // Closes on losing focus like the Mac panel, except while a screenshot is
    // being taken: the capture overlay takes the focus and must not close it.
    let window_for_blur = window.clone();
    window.on_window_event(move |event| {
        if let WindowEvent::Focused(false) = event {
            if file_drag::is_dragging() {
                return;
            }
            capture_overlay::hide_unless_capturing(window_for_blur.clone());
        }
    });
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
    show_spotlight(app);
}

/// Opens the Spotlight panel (centered on the monitor under the cursor).
/// Also what launching the app a second time does, like the Mac Dock click.
pub fn show_spotlight(app: &AppHandle) {
    let window = ensure_spotlight(app);

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

    capture_overlay::cancel_pending_hide();
    let _ = window.show();
    let _ = window.set_focus();
    let _ = app.emit_to(SPOTLIGHT_LABEL, "spotlight-shown", ());
}
