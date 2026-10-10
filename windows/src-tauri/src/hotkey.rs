use tauri::AppHandle;
use tauri_plugin_global_shortcut::{GlobalShortcutExt, ShortcutState};

use crate::services::{capture, hotkey_preferences};
use crate::windows_ui;

/// Fixed, non-customizable equivalents of macOS's Cmd+Shift+3/4 — unlike the
/// Spotlight hotkey below, these just trigger Windows' own screenshot tools,
/// so there's no "current value" to store or display in Settings.
const FULL_SCREEN_CAPTURE_HOTKEY: &str = "Alt+Shift+3";
const REGION_CAPTURE_HOTKEY: &str = "Alt+Shift+4";

/// Registers the persisted shortcut at startup. Mirrors
/// `AppDelegate.registerHotKey()`.
pub fn init(app: &AppHandle) {
    let current = hotkey_preferences::current();
    if let Err(err) = apply(app, &current) {
        eprintln!("Failed to register hotkey '{current}': {err}");
    }
}

/// Unregisters only the previously-bound Spotlight hotkey (not
/// `unregister_all()` — that would also wipe the fixed capture shortcuts
/// registered by `init_capture_shortcuts`) and registers `hotkey_str` with
/// a handler that toggles the Spotlight panel.
pub fn apply(app: &AppHandle, hotkey_str: &str) -> Result<(), String> {
    let global_shortcut = app.global_shortcut();
    let _ = global_shortcut.unregister(hotkey_preferences::current().as_str());

    let app_for_handler = app.clone();
    global_shortcut
        .on_shortcut(hotkey_str, move |_app, _shortcut, event| {
            if event.state == ShortcutState::Pressed {
                windows_ui::toggle_spotlight(&app_for_handler);
            }
        })
        .map_err(|e| e.to_string())
}

/// Registers the fixed full-screen and region capture shortcuts at startup.
/// Each just simulates Windows' own screenshot tool (`capture.rs`) — the
/// existing file/clipboard watchers pick up the result from there.
pub fn init_capture_shortcuts(app: &AppHandle) {
    let global_shortcut = app.global_shortcut();

    if let Err(err) = global_shortcut.on_shortcut(FULL_SCREEN_CAPTURE_HOTKEY, |_app, _shortcut, event| {
        if event.state == ShortcutState::Pressed {
            capture::trigger_full_screen_capture();
        }
    }) {
        eprintln!("Failed to register '{FULL_SCREEN_CAPTURE_HOTKEY}': {err}");
    }

    if let Err(err) = global_shortcut.on_shortcut(REGION_CAPTURE_HOTKEY, |_app, _shortcut, event| {
        if event.state == ShortcutState::Pressed {
            capture::trigger_region_capture();
        }
    }) {
        eprintln!("Failed to register '{REGION_CAPTURE_HOTKEY}': {err}");
    }
}
