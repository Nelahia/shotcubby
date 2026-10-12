# ShotCubby

Every screenshot you take, automatically collected in one folder and one click away.
A small menu bar (macOS) / system tray (Windows) app.

![Menu Bar](assets/menubar-overview.png)

## Why

Screenshots pile up on the Desktop, get lost in Downloads, or vanish in the
clipboard. ShotCubby quietly catches all of them, files them in a single place,
and lets you find, copy or rename any of them in a couple of keystrokes.

- **Nothing to do** — keep taking screenshots the way you already do.
- **One place** — `~/ShotCubby` (macOS) or `%USERPROFILE%\ShotCubby` (Windows).
- **Fast to reach** — a Spotlight-style search opens from anywhere.
- **Safe** — deleting always goes to the Trash / Recycle Bin, never permanently.
- **Private** — works entirely on your machine: no account, no tracking, your
  screenshots never leave it. The only network request is the update check
  (see [Updates](#updates)).

## What it captures

| macOS | Windows | What happens |
|---|---|---|
| `Cmd + Shift + 3` | `Alt + Shift + 3` | Full screen → filed in your ShotCubby folder |
| `Cmd + Shift + 4` | `Alt + Shift + 4` | Selected area → filed in your ShotCubby folder |
| `Cmd + Shift + Ctrl + 3 / 4` | `Win + Shift + S` | Copied to the clipboard → saved to your ShotCubby folder |

On Windows the capture shortcuts can be changed freely in **Settings**; on macOS
the system's own screenshot shortcuts are used.

## Using it

**On macOS the app also sits in the Dock**: clicking its icon opens the search panel (turn it off in Settings → Show in the Dock).
**On Windows**, launching ShotCubby again (Start menu, desktop shortcut, or its pinned taskbar icon) opens the search panel in the running copy instead of starting a second one — pin it to the taskbar for a one-click icon.

**Click the menu bar / tray icon** for your recent screenshots, grouped by day, with
thumbnails. Click one to open it; hover to copy, reveal in the file manager or delete;
double-click a name to rename it.

**Open the search from anywhere** with the global shortcut (default
`Cmd + /` on macOS, `Ctrl + /` on Windows — both customizable in Settings),
then type to filter and use the keyboard:

| Action | macOS | Windows |
|---|---|---|
| Move in the list | `↑` `↓` | `↑` `↓` |
| Preview | `↩` | `Enter` |
| Copy | `Cmd + C` | `Ctrl + C` |
| Rename | `Cmd + E` | `Ctrl + E` |
| Open folder | `Cmd + R` | `Ctrl + R` |
| Move to Trash | `Cmd + ⌫` | `Ctrl + ⌫` |
| All actions menu | `Cmd + K` | `Ctrl + K` |
| Settings | `Cmd + ,` | `Ctrl + ,` |
| Close | `Esc` | `Esc` |

**Settings** let you change the search shortcut (and, on Windows, the capture
shortcuts) and pick a custom screenshot folder.

## Install

Download the installer for your system from the
[latest release](https://github.com/Nelahia/shotcubby/releases/latest):

- **macOS 14+**: `ShotCubby.dmg`, then drag the app to Applications.
- **Windows 10/11**: `ShotCubby-Setup.exe` (or `ShotCubby.msi`).

To start ShotCubby at login on macOS: **System Settings → General → Login Items → +**.

## Updates

- **Windows**: ShotCubby checks for a new version a few seconds after launch, then every
  few hours, and installs it automatically before restarting. Each update is verified
  against the project's signing key, so only releases published by the maintainer can
  install. The check is a single request to this repository's
  [GitHub releases](https://github.com/Nelahia/shotcubby/releases); it sends no
  personal data and no identifier. Turn it off in **Settings → Install updates
  automatically**.
- **macOS**: ShotCubby checks for a new version about once a day (and on **Settings →
  Check for Updates…**, or from the right-click menu of the menu bar icon). When one is
  available, a window offers to install it; the download is verified against the
  project's signing key before it replaces the app, and ShotCubby restarts. This is done
  with [Sparkle](https://sparkle-project.org). The check is a single request to this
  repository's [GitHub releases](https://github.com/Nelahia/shotcubby/releases) and sends
  no personal data. Turn the automatic checks off in Settings.

## Code signing policy

Windows installers are signed through the free open-source program of the
SignPath Foundation: free code signing provided by [SignPath.io](https://signpath.io),
certificate by [SignPath Foundation](https://signpath.org).

- Only binaries built by the [release workflow](.github/workflows/release.yml)
  from this repository's tagged source are submitted for signing.
- The maintainer ([Nelahia](https://github.com/Nelahia)) is the sole author,
  reviewer and approver of signing requests.
- **Privacy**: ShotCubby works entirely on your machine. It does not collect or
  send any data. The only network request the app makes is the optional
  update check described in [Updates](#updates), which sends nothing about you.

## License

[MIT](LICENSE)

ShotCubby is provided as is, without warranty of any kind — see [LICENSE](LICENSE). To report a security problem, see [SECURITY.md](SECURITY.md).
