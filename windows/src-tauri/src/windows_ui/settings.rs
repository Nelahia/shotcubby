use tauri::{AppHandle, Manager, WebviewUrl, WebviewWindow, WebviewWindowBuilder, WindowEvent};

use super::SETTINGS_LABEL;

/// Returns the Settings window, creating it (hidden) on first use. A plain
/// titled window — the only one of the three meant to be moved/closed like
/// a normal window, so it opts out of the other two's hide-on-blur behavior.
pub fn ensure_settings(app: &AppHandle) -> WebviewWindow {
    if let Some(window) = app.get_webview_window(SETTINGS_LABEL) {
        return window;
    }

    let window = WebviewWindowBuilder::new(app, SETTINGS_LABEL, WebviewUrl::App("settings.html".into()))
        .title("ShotCubby Settings")
        .inner_size(440.0, 170.0)
        .resizable(false)
        .minimizable(false)
        .maximizable(false)
        .visible(false)
        .build()
        .expect("failed to build settings window");

    // A background utility never really "quits" its settings window, it just
    // hides it — matches the Mac window's `isReleasedWhenClosed = false`.
    let window_for_closure = window.clone();
    window.on_window_event(move |event| {
        if let WindowEvent::CloseRequested { api, .. } = event {
            api.prevent_close();
            let _ = window_for_closure.hide();
        }
    });

    window
}

pub fn open_settings(app: &AppHandle) {
    let window = ensure_settings(app);
    let _ = window.show();
    let _ = window.center();
    let _ = window.set_focus();
}
