pub mod capture;
pub mod clipboard_watcher;
pub mod config_store;
pub mod folder_preferences;
pub mod hotkey_action;
pub mod hotkey_preferences;
pub mod screenshot_matching;
pub mod screenshot_watcher;
pub mod storage;
pub mod thumbnails;
pub mod update_preferences;
pub mod updater;

pub use clipboard_watcher::ClipboardWatcher;
pub use screenshot_watcher::{AccessFailure, ScreenshotWatcher};
