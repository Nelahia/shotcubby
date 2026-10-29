mod app_state;
mod commands;
mod hotkey;
mod models;
mod services;
mod windows_ui;

use tauri::menu::{Menu, MenuBuilder};
use tauri::tray::{MouseButton, MouseButtonState, TrayIcon, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Manager, RunEvent};

use app_state::AppStateInner;
use services::i18n::tr;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app = tauri::Builder::default()
        // First, so a second launch is intercepted before anything else starts:
        // it opens the search in the running copy instead of starting another
        // tray icon (same as clicking the Dock icon on macOS).
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            windows_ui::show_spotlight(app);
        }))
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_autostart::init(tauri_plugin_autostart::MacosLauncher::LaunchAgent, None))
        .invoke_handler(tauri::generate_handler![
            commands::list_screenshots,
            commands::get_access_failure,
            commands::get_vault_dir,
            commands::get_vault_info,
            commands::choose_vault_folder,
            commands::move_vault,
            commands::get_screenshot_dir,
            commands::get_thumbnail,
            commands::open_screenshot,
            commands::start_file_drag,
            commands::reveal_screenshot,
            commands::copy_screenshot,
            commands::delete_screenshot,
            commands::rename_screenshot,
            commands::choose_custom_folder,
            commands::retry_screenshot_access,
            commands::open_vault_folder,
            commands::open_windows_security,
            commands::get_hotkeys,
            commands::set_hotkey,
            commands::reset_hotkey,
            commands::get_ai_rename,
            commands::get_ai_last_result,
            commands::set_ai_rename_enabled,
            commands::set_ai_rename_provider,
            commands::set_ai_rename_instructions,
            commands::save_api_key,
            commands::delete_api_key,
            commands::test_api_key,
            commands::get_language,
            commands::get_language_preference,
            commands::set_language_preference,
            commands::get_theme,
            commands::set_theme,
            commands::get_launch_at_login,
            commands::set_launch_at_login,
            commands::get_organize_by_day,
            commands::set_organize_by_day,
            commands::get_auto_update,
            commands::set_auto_update,
            commands::get_update_status,
            commands::check_for_updates,
            commands::open_spotlight_from_popover,
            commands::open_settings_window,
            commands::show_copy_toast,
            commands::quit_app,
        ])
        .setup(|app| {
            services::language::init();
            let handle = app.handle().clone();
            let state = AppStateInner::init(handle.clone());
            app.manage(state);

            setup_tray(app)?;

            // Created eagerly, on the main thread, during setup. Two reasons:
            // the hide-on-blur listener needs to be wired up from the start
            // (mirrors the Mac app building its popover and Spotlight panel
            // once in `applicationDidFinishLaunching`), and window creation
            // on Windows has thread affinity — building one later from an
            // IPC command handler (which runs on a worker thread, not the
            // main thread) hangs. Settings is otherwise only ever opened
            // from a command, so it needs the same eager treatment.
            windows_ui::ensure_popover(&handle);
            windows_ui::ensure_spotlight(&handle);
            windows_ui::ensure_settings(&handle);
            windows_ui::ensure_toast(&handle);
            windows_ui::ensure_copy_toast(&handle);

            services::launch_at_login::apply_default(&handle);
            hotkey::init(&handle);
            services::updater::start(handle.clone());

            app.state::<AppStateInner>().start();
            services::day_archive::start(handle.clone());

            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building ShotCubby");

    app.run(|_app_handle, event| {
        // A tray utility only exits via the Quit menu item / command
        // (`commands::quit_app`, which calls `app.exit(0)`) — closing a
        // window (e.g. Settings) must never take the whole app down with it.
        // That window case arrives without an exit code; an explicit
        // `exit(code)` carries one and must go through, or Quit does nothing.
        if let RunEvent::ExitRequested { code: None, api, .. } = event {
            api.prevent_exit();
        }
    });
}

fn tray_menu(app: &impl Manager<tauri::Wry>) -> tauri::Result<Menu<tauri::Wry>> {
    MenuBuilder::new(app)
        .text("search", tr("Search…"))
        .text("open_folder", tr("Open Folder"))
        .text("settings", tr("Settings…"))
        .text("check_update", tr("Check for Updates…"))
        .separator()
        .text("quit", tr("Quit ShotCubby"))
        .build()
}

/// Redraws the tray menu in the current language (after the choice changed in Settings).
pub(crate) fn refresh_tray(app: &AppHandle) {
    if let Ok(menu) = tray_menu(app) {
        let _ = app.state::<TrayIcon>().set_menu(Some(menu));
    }
}

fn setup_tray(app: &tauri::App) -> tauri::Result<()> {
    let menu = tray_menu(app)?;

    let icon = tauri::image::Image::from_bytes(include_bytes!("../icons/tray-icon.png"))?;

    let tray = TrayIconBuilder::new()
        .icon(icon)
        .tooltip(format!("ShotCubby {}", app.package_info().version))
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "search" => windows_ui::toggle_spotlight(app),
            "open_folder" => {
                let _ = commands::open_vault_folder(app.clone(), app.state());
            }
            "settings" => windows_ui::open_settings(app),
            "check_update" => {
                windows_ui::open_settings(app);
                let app = app.clone();
                tauri::async_runtime::spawn(async move {
                    services::updater::check_and_install(&app).await;
                });
            }
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                rect,
                ..
            } = event
            {
                windows_ui::toggle_popover_near_tray(tray.app_handle(), rect);
            }
        })
        .build(app)?;

    // Must be kept alive for the app's lifetime — dropping the returned
    // handle can make the OS tray icon disappear.
    app.manage(tray);

    Ok(())
}
