use tauri::AppHandle;
use tauri_plugin_global_shortcut::{GlobalShortcutExt, ShortcutState};

use crate::services::capture;
use crate::services::hotkey_action::HotkeyAction;
use crate::services::hotkey_preferences;
use crate::windows_ui;

/// Registers every persisted shortcut at startup. Mirrors
/// `AppDelegate.registerHotKey()`.
pub fn init(app: &AppHandle) {
    for action in HotkeyAction::ALL {
        let current = hotkey_preferences::current(action);
        if let Err(err) = register(app, action, &current) {
            eprintln!("Failed to register hotkey '{current}' for {}: {err}", action.id());
        }
    }
}

/// Rebinds `action` to `hotkey_str`. The new combo is registered before the
/// old one is released, so a combo that is refused (already taken by another
/// action or another app) leaves the working binding untouched.
pub fn apply(app: &AppHandle, action: HotkeyAction, hotkey_str: &str) -> Result<(), String> {
    let previous = hotkey_preferences::current(action);
    if previous.eq_ignore_ascii_case(hotkey_str) {
        return Ok(());
    }
    register(app, action, hotkey_str)?;
    let _ = app.global_shortcut().unregister(previous.as_str());
    Ok(())
}

fn register(app: &AppHandle, action: HotkeyAction, hotkey_str: &str) -> Result<(), String> {
    app.global_shortcut()
        .on_shortcut(hotkey_str, move |app, _shortcut, event| {
            if event.state == ShortcutState::Pressed {
                run(app, action);
            }
        })
        .map_err(|e| e.to_string())
}

/// Spotlight toggles its panel; the capture shortcuts just trigger Windows'
/// own screenshot tools (`capture.rs`) — the existing file/clipboard
/// watchers pick up the result from there.
///
/// This runs inside the shortcut plugin's handler, which holds the plugin's
/// lock for as long as it takes. Opening the screenshot tool (`ShellExecuteExW`)
/// waits by dispatching window messages, so another shortcut pressed meanwhile
/// re-enters the plugin on the same thread, asks for the lock it already holds
/// and freezes the whole app (tray, windows, every shortcut). The captures
/// therefore leave the handler at once and run on their own thread.
fn run(app: &AppHandle, action: HotkeyAction) {
    match action {
        HotkeyAction::Spotlight => windows_ui::toggle_spotlight(app),
        HotkeyAction::FullScreenCapture => {
            std::thread::spawn(capture::trigger_full_screen_capture);
        }
        HotkeyAction::RegionCapture => {
            let app = app.clone();
            std::thread::spawn(move || capture::trigger_region_capture(&app));
        }
    }
}
