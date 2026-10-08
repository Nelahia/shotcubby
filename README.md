# ShotKeep

A lightweight macOS menu bar app that automatically captures, organizes, and stores all your screenshots in one place.

![Menu Bar](assets/menubar-overview.png)

## What it does

ShotKeep lives in your menu bar as a small folder icon and works silently in the background.

![Icon](assets/menubar-icon.png)

**It captures screenshots from two sources:**

| Shortcut | macOS behavior | ShotKeep behavior |
|---|---|---|
| `Cmd + Shift + 3` | Saves full screen to Desktop | Detects the new file, moves it to `~/ShotKeep/` |
| `Cmd + Shift + 4` | Saves selection to Desktop | Detects the new file, moves it to `~/ShotKeep/` |
| `Cmd + Shift + Ctrl + 3` | Copies full screen to clipboard | Detects clipboard image, saves it to `~/ShotKeep/` |
| `Cmd + Shift + Ctrl + 4` | Copies selection to clipboard | Detects clipboard image, saves it to `~/ShotKeep/` |

**Click the folder icon to access your screenshots:**

- Thumbnail preview for each screenshot
- Click to open in Preview
- Hover to reveal actions: **copy**, **reveal in Finder**, **delete**
- Screenshot count in the header
- "Open Folder" to jump to `~/ShotKeep/` in Finder

## How it works

```
┌─────────────────────────────────────────────────┐
│                    ShotKeep                     │
│                                                 │
│   ┌──────────────┐     ┌──────────────────┐     │
│   │ File Watcher │────▶│                  │     │
│   │  (FSEvents)  │     │    ~/ShotKeep/   │     │
│   └──────────────┘     │                  │     │
│                        │  Organized PNG   │     │
│   ┌──────────────┐     │  storage with    │     │
│   │  Clipboard   │────▶│  thumbnails      │     │
│   │   Watcher    │     │                  │     │
│   └──────────────┘     └──────────────────┘     │
│                              │                  │
│                              ▼                  │
│                     ┌────────────────┐          │
│                     │ Menu Bar       │          │
│                     │ Popover UI     │          │
│                     └────────────────┘          │
└─────────────────────────────────────────────────┘
```

- **File Watcher** — Monitors your screenshot directory (Desktop by default) using macOS FSEvents. When a new screenshot file appears, it moves it to `~/ShotKeep/`.
- **Clipboard Watcher** — Polls the system pasteboard every 0.8s. When a new image is copied via `Cmd+Shift+Ctrl`, it saves it as a PNG in `~/ShotKeep/`.
- **Popover UI** — SwiftUI view with async thumbnails (via QuickLookThumbnailing), hover actions, and quick access.

## Installation

### Homebrew (recommended)

```bash
brew tap nelahia/tap
brew install --cask shotkeep
```

### Manual download

1. Download `ShotKeep.dmg` from the [latest release](https://github.com/Nelahia/shotkeep/releases/latest)
2. Open the disk image and drag `ShotKeep.app` to `/Applications`
3. Launch ShotKeep from Applications

Releases are **signed with a Developer ID Application certificate and notarized by Apple**, so the app opens with no Gatekeeper warning.

### Build from source

Requires macOS 14.0+, Xcode 16+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/Nelahia/shotkeep.git
cd shotkeep
brew install xcodegen
xcodegen generate
xcodebuild -project ShotKeep.xcodeproj \
  -scheme ShotKeep \
  -configuration Release \
  -derivedDataPath build
open build/Build/Products/Release/ShotKeep.app
```

### Launch at login (optional)

1. Open **System Settings** → **General** → **Login Items**
2. Click **+** and select `ShotKeep.app`

## Project structure

```
ShotKeep/
├── ShotKeepApp.swift              # Entry point, AppDelegate, NSStatusItem
├── AppState.swift                 # Observable state manager
├── Services/
│   ├── ScreenshotWatcher.swift    # FSEvents file system watcher
│   ├── ScreenshotStorage.swift    # File operations (move, load, delete)
│   └── ClipboardWatcher.swift     # Pasteboard monitor for clipboard screenshots
├── Models/
│   └── ScreenshotItem.swift       # Screenshot data model
├── Views/
│   ├── PopoverView.swift          # Main popover layout
│   ├── ScreenshotRow.swift        # Individual screenshot row with actions
│   ├── AsyncThumbnail.swift       # Async thumbnail via QuickLookThumbnailing
│   └── EmptyStateView.swift       # Empty state placeholder
├── Info.plist
└── ShotKeep.entitlements
```

## Tech stack

- **Swift 5.9** + **SwiftUI** + **AppKit**
- **FSEvents** via `DispatchSource` for file monitoring
- **NSPasteboard** polling for clipboard capture
- **QuickLookThumbnailing** for async thumbnail generation
- **No external dependencies**

## Release process

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds, signs with a
Developer ID Application certificate, notarizes via the App Store Connect API, and
packages the app as a `.dmg`. It requires these GitHub repo secrets to be set (no values
here, just names):

| Secret | Purpose |
|---|---|
| `APPLE_CERTIFICATE_P12_BASE64` | Base64 of the exported Developer ID Application `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Password protecting that `.p12` |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_API_KEY_ID` | App Store Connect API key ID (used for notarization) |
| `APPLE_API_ISSUER_ID` | App Store Connect API issuer ID |
| `APPLE_API_KEY_P8_BASE64` | Base64 of the App Store Connect API private key (`.p8`) |

After a release, bump `url`/`version`/`sha256` in the `shotkeep` cask over in
`nelahia/homebrew-tap`.

## License

MIT
