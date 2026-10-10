use windows::Win32::UI::Input::KeyboardAndMouse::{
    SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, KEYBDINPUT, KEYBD_EVENT_FLAGS, KEYEVENTF_KEYUP,
    VIRTUAL_KEY, VK_LWIN, VK_SHIFT, VK_SNAPSHOT,
};

/// Win32 has no named constant for letter keys — their virtual-key code is
/// just the ASCII value.
const VK_S: VIRTUAL_KEY = VIRTUAL_KEY(0x53);

/// Simulates `Win+PrtScn`: Windows writes a full-screen capture straight to
/// a file in `Pictures\Screenshots`, which `screenshot_watcher` already
/// watches — no separate capture code needed here.
pub fn trigger_full_screen_capture() {
    send(&[
        key_event(VK_LWIN, false),
        key_event(VK_SNAPSHOT, false),
        key_event(VK_SNAPSHOT, true),
        key_event(VK_LWIN, true),
    ]);
}

/// Simulates `Win+Shift+S`: opens Windows' own region-capture tool, result
/// copied to the clipboard, which `clipboard_watcher` already watches.
pub fn trigger_region_capture() {
    send(&[
        key_event(VK_LWIN, false),
        key_event(VK_SHIFT, false),
        key_event(VK_S, false),
        key_event(VK_S, true),
        key_event(VK_SHIFT, true),
        key_event(VK_LWIN, true),
    ]);
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
