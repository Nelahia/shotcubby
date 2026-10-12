# ShotCubby for Windows

A Windows port of the macOS [ShotCubby](../macos) menu-bar app: it watches for
screenshots (file-based and clipboard-based), files them into `%USERPROFILE%\ShotCubby`,
and gives quick access through a tray popover and a Spotlight-style global search panel.

Built with [Tauri](https://tauri.app) (Rust backend, vanilla HTML/CSS/JS frontend) —
light and dependency-free in the same spirit as the Swift/SwiftUI original.

## What it does

- Watches `Pictures\Screenshots` (where `Win+PrtScn` saves full-screen captures) and
  moves new screenshots into `%USERPROFILE%\ShotCubby`.
- Polls the clipboard for images (e.g. from `Win+Shift+S`) and saves them into the same
  vault, tagged `(clipboard)`.
- Tray icon → click for a popover (thumbnails grouped by day, hover to copy/reveal/
  delete, double-click a name to rename). Right-click for Search…/Open Folder/Settings…/
  Quit.
- A global shortcut (default **Ctrl+/**) opens a Spotlight-style search panel: type to
  filter, arrow keys to move, Enter to preview, Ctrl+C to copy, Ctrl+R to reveal,
  Ctrl+E to rename, Ctrl+Backspace to delete, Ctrl+K for all actions, Ctrl+, for
  Settings, Esc to close.
- Full-screen and region captures have their own global shortcuts (default
  **Alt+Shift+3** / **Alt+Shift+4**). Every shortcut can be rebound in Settings.
- Only one copy runs: launching the app again (Start menu, shortcut, pinned taskbar icon)
  opens the search panel in the running one.
- Deletes always go to the Recycle Bin — never a permanent delete.

## Requirements

- Rust (stable) + Cargo
- Node.js + npm
- Windows 10/11 (uses WebView2, preinstalled on current Windows)

## Run in development

```bash
npm install
npm run dev
```

## Build an installer

```bash
npm run build
```

Produces an NSIS and MSI installer under `src-tauri/target/release/bundle/`.

## Known differences from the Mac version

- **Unsigned**: there's no code-signing certificate for this build, so Windows will
  show a SmartScreen warning on first run — the Mac build is notarized, this one isn't
  (yet).
- **No "launch at login" toggle** in Settings — same as the Mac app, which also
  requires the user to add it manually (System Settings → Login Items there; the
  Startup folder, or Task Scheduler, here). Can be added later if wanted.
- **Access-failure card** is simplified: Windows doesn't have macOS's TCC permission
  model, so it only distinguishes "folder missing" from "Windows is blocking access"
  (e.g. Controlled Folder Access) rather than the Mac version's finer-grained cases.

## Project layout

```
apps/windows/
├── src-tauri/          Rust backend
│   └── src/
│       ├── lib.rs          tray + window + hotkey wiring (thin)
│       ├── app_state.rs    shared in-memory state
│       ├── commands.rs     #[tauri::command] handlers (thin, call services)
│       ├── hotkey.rs       global shortcut (de)registration
│       ├── windows_ui.rs   window creation/show/hide/positioning
│       ├── models/         ScreenshotItem
│       └── services/       storage, screenshot watcher, clipboard watcher,
│                           preferences, thumbnails — all the actual logic
└── src/                 Frontend (no build step — plain ES modules)
    ├── shared.css / shared.js   theme tokens + helpers shared by all views
    ├── popover.html / .js      tray popover
    ├── spotlight.html / .js    global search panel
    └── settings.html / .js     hotkey settings
```

## Updates

The app checks this repository's GitHub releases a few seconds after launch and every
6 hours, then downloads, verifies (against the public key in `tauri.conf.json`) and
installs a newer release before restarting. Switch it off in Settings. The release
workflow signs the installer with the update key (`TAURI_SIGNING_PRIVATE_KEY` secrets)
and publishes `latest.json` next to it.
