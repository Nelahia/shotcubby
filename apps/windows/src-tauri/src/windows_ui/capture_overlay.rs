use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use tauri::WebviewWindow;
use windows::Win32::Foundation::CloseHandle;
use windows::Win32::System::Threading::{
    OpenProcess, PROCESS_NAME_WIN32, PROCESS_QUERY_LIMITED_INFORMATION, QueryFullProcessImageNameW,
};
use windows::Win32::UI::WindowsAndMessaging::{GetForegroundWindow, GetWindowThreadProcessId};
use windows::core::PWSTR;

/// The programs that take the focus while a screenshot is being taken: the
/// Win+Shift+S overlay and the Snipping Tool itself.
const CAPTURE_PROGRAMS: [&str; 3] = ["screenclippinghost.exe", "snippingtool.exe", "screensketch.exe"];

const DECIDE_TICK: Duration = Duration::from_millis(50);
const DECIDE_TICKS: u32 = 6;
const WAIT_TICK: Duration = Duration::from_millis(150);
const WAIT_MAX_TICKS: u32 = 400;

/// Counts the blurs and the reopenings: a pending decision only goes through
/// while nothing newer happened.
static GENERATION: AtomicU64 = AtomicU64::new(0);

/// Called when the Spotlight is shown again, so a hide still pending from its
/// last blur cannot close it.
pub fn cancel_pending_hide() {
    GENERATION.fetch_add(1, Ordering::SeqCst);
}

/// File name (lowercase) of the program owning the foreground window.
fn foreground_program() -> Option<String> {
    unsafe {
        let hwnd = GetForegroundWindow();
        if hwnd.is_invalid() {
            return None;
        }
        let mut pid = 0u32;
        GetWindowThreadProcessId(hwnd, Some(&mut pid));
        if pid == 0 {
            return None;
        }
        let process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid).ok()?;
        let mut buffer = [0u16; 520];
        let mut length = buffer.len() as u32;
        let queried =
            QueryFullProcessImageNameW(process, PROCESS_NAME_WIN32, PWSTR(buffer.as_mut_ptr()), &mut length);
        let _ = CloseHandle(process);
        queried.ok()?;
        let path = String::from_utf16_lossy(&buffer[..length as usize]);
        path.rsplit('\\').next().map(str::to_lowercase)
    }
}

fn capture_in_progress() -> bool {
    foreground_program().is_some_and(|name| CAPTURE_PROGRAMS.contains(&name.as_str()))
}

/// Hides `window` after it lost focus, unless the focus went to a screenshot
/// tool: then it stays open, and takes the focus back once the capture is
/// over, so a capture never closes the Spotlight. The foreground window takes
/// a moment to settle after a focus change, hence the short look-ahead.
pub fn hide_unless_capturing(window: WebviewWindow) {
    let generation = GENERATION.fetch_add(1, Ordering::SeqCst) + 1;
    let still_current = move || GENERATION.load(Ordering::SeqCst) == generation;
    std::thread::spawn(move || {
        for _ in 0..DECIDE_TICKS {
            if !still_current() || window.is_focused().unwrap_or(false) {
                return;
            }
            if capture_in_progress() {
                if wait_for_capture_end(&still_current) {
                    let _ = window.set_focus();
                }
                return;
            }
            std::thread::sleep(DECIDE_TICK);
        }
        if still_current() {
            let _ = window.hide();
        }
    });
}

/// Waits for the screenshot tool to leave the foreground; `false` if the
/// Spotlight was reopened or blurred again meanwhile (the newer decision wins).
fn wait_for_capture_end(still_current: &impl Fn() -> bool) -> bool {
    for _ in 0..WAIT_MAX_TICKS {
        std::thread::sleep(WAIT_TICK);
        if !still_current() {
            return false;
        }
        if !capture_in_progress() {
            return true;
        }
    }
    true
}
