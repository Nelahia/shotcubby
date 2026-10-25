mod capture_overlay;
mod copy_toast;
mod popover;
mod settings;
mod spotlight;
mod toast;

pub use copy_toast::{ensure_copy_toast, show_copy_toast};
pub use popover::{ensure_popover, toggle_popover_near_tray};
pub use settings::{ensure_settings, open_settings};
pub use spotlight::{ensure_spotlight, show_spotlight, toggle_spotlight};
pub use toast::{ensure_toast, show_toast};

use tauri::{WebviewWindow, WindowEvent};

pub const POPOVER_LABEL: &str = "popover";
pub const SPOTLIGHT_LABEL: &str = "spotlight";
pub const SETTINGS_LABEL: &str = "settings";
pub const TOAST_LABEL: &str = "toast";
pub const COPY_TOAST_LABEL: &str = "copy-toast";

/// Shared by all three windows: the Mac equivalents (`NSPopover`'s
/// `.transient` behavior, `SpotlightPanel.resignKey`) all close on losing
/// focus, so Settings — the one regular, movable window — is the
/// only one that opts out (see `settings.rs`).
fn hide_on_blur(window: &WebviewWindow) {
    let window_for_closure = window.clone();
    window.on_window_event(move |event| {
        if let WindowEvent::Focused(false) = event {
            let _ = window_for_closure.hide();
        }
    });
}
