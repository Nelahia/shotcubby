use tauri::{AppHandle, Manager, PhysicalPosition, WebviewUrl, WebviewWindow, WebviewWindowBuilder};

use super::{hide_on_blur, POPOVER_LABEL};

const POPOVER_SIZE: (f64, f64) = (360.0, 480.0);

/// Returns the popover window, creating it (hidden) on first use. Mirrors
/// the Mac app's reused `NSPopover` instance.
pub fn ensure_popover(app: &AppHandle) -> WebviewWindow {
    if let Some(window) = app.get_webview_window(POPOVER_LABEL) {
        return window;
    }

    let window = WebviewWindowBuilder::new(app, POPOVER_LABEL, WebviewUrl::App("popover.html".into()))
        .title("ShotCubby")
        .inner_size(POPOVER_SIZE.0, POPOVER_SIZE.1)
        .resizable(false)
        .decorations(false)
        .always_on_top(true)
        .skip_taskbar(true)
        .visible(false)
        // The native shadow on a borderless window makes Windows 11 draw its own
        // rounded frame and border around the (already rounded, transparent) page.
        .shadow(false)
        .transparent(true)
        .build()
        .expect("failed to build popover window");

    hide_on_blur(&window);
    window
}

/// Toggles the popover, positioning it just above the tray icon (Windows'
/// tray sits at the bottom of the screen, unlike the Mac menu bar's top).
pub fn toggle_popover_near_tray(app: &AppHandle, tray_rect: tauri::Rect) {
    let window = ensure_popover(app);
    if window.is_visible().unwrap_or(false) {
        let _ = window.hide();
        return;
    }

    let scale_factor = window.scale_factor().unwrap_or(1.0);
    let icon_pos = tray_rect.position.to_physical::<f64>(scale_factor);
    let icon_size = tray_rect.size.to_physical::<f64>(scale_factor);

    let x = icon_pos.x + icon_size.width - POPOVER_SIZE.0;
    let y = icon_pos.y - POPOVER_SIZE.1 - 8.0;

    let _ = window.set_position(PhysicalPosition::new(x.max(0.0), y.max(0.0)));
    let _ = window.show();
    let _ = window.set_focus();
}
