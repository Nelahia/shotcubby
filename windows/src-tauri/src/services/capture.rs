use tauri::AppHandle;
use tauri_plugin_opener::OpenerExt;
use windows::Win32::UI::Input::KeyboardAndMouse::{
    SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, KEYBDINPUT, KEYBD_EVENT_FLAGS, KEYEVENTF_KEYUP,
    VIRTUAL_KEY, VK_LWIN, VK_MENU, VK_SHIFT, VK_SNAPSHOT,
};
use windows::Win32::System::Diagnostics::Debug::MessageBeep;
use windows::Win32::UI::WindowsAndMessaging::MB_OK;

/// Unassigned virtual-key code, injected before releasing Alt so the
/// foreground app doesn't treat the lone Alt release as "open the menu bar".
const VK_UNASSIGNED: VIRTUAL_KEY = VIRTUAL_KEY(0xE8);

/// Simulates `Win+PrtScn`: Windows writes a full-screen capture straight to
/// a file in `Pictures\Screenshots`, which `screenshot_watcher` already
/// watches — no separate capture code needed here. The hotkey's Alt+Shift
/// are still physically held when it fires, so they're released first —
/// otherwise Windows sees `Win+Alt+PrtScn` (Game Bar's active-window capture).
pub fn trigger_full_screen_capture() {
    send(&[
        key_event(VK_UNASSIGNED, false),
        key_event(VK_UNASSIGNED, true),
        key_event(VK_MENU, true),
        key_event(VK_SHIFT, true),
        key_event(VK_LWIN, false),
        key_event(VK_SNAPSHOT, false),
        key_event(VK_SNAPSHOT, true),
        key_event(VK_LWIN, true),
    ]);
}

/// Opens Windows' own region-capture overlay (the same one as `Win+Shift+S`)
/// through its `ms-screenclip:` URI, result copied to the clipboard, which
/// `clipboard_watcher` already watches. Not a simulated `Win+Shift+S`: the
/// hotkey's Alt is still physically held when it fires, so Windows would
/// see `Win+Alt+Shift+S` and ignore it.
pub fn trigger_region_capture(app: &AppHandle) {
    if let Err(err) = app.opener().open_url("ms-screenclip:", None::<&str>) {
        eprintln!("Failed to open region capture: {err}");
    }
}

/// Short system sound as feedback that a capture was saved. Windows plays
/// one of its own for `Win+Shift+S` (via the Snipping Tool's own setting),
/// but not for `Win+PrtScn` — this covers that gap for every capture path,
/// called from the single place (`app_state.rs`) where a new screenshot
/// lands in the vault, regardless of what triggered it.
pub fn play_capture_sound() {
    unsafe {
        let _ = MessageBeep(MB_OK);
    }
}

fn key_event(vk: VIRTUAL_KEY, key_up: bool) -> INPUT {
    INPUT {
        r#type: INPUT_KEYBOARD,
        Anonymous: INPUT_0 {
            ki: KEYBDINPUT {
                wVk: vk,
                wScan: 0,
                dwFlags: if key_up { KEYEVENTF_KEYUP } else { KEYBD_EVENT_FLAGS(0) },
                time: 0,
                dwExtraInfo: 0,
            },
        },
    }
}

fn send(inputs: &[INPUT]) {
    unsafe {
        let _ = SendInput(inputs, std::mem::size_of::<INPUT>() as i32);
    }
}
