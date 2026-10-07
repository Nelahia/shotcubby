# VaultyShot

A lightweight macOS menu bar app that automatically captures, organizes, and stores all your screenshots in one place.

![Menu Bar](assets/menubar-overview.png)

## What it does

VaultyShot lives in your menu bar as a small folder icon and works silently in the background.

![Icon](assets/menubar-icon.png)

**It captures screenshots from two sources:**

| Shortcut | macOS behavior | VaultyShot behavior |
|---|---|---|
| `Cmd + Shift + 3` | Saves full screen to Desktop | Detects the new file, moves it to `~/VaultyShot/` |
| `Cmd + Shift + 4` | Saves selection to Desktop | Detects the new file, moves it to `~/VaultyShot/` |
| `Cmd + Shift + Ctrl + 3` | Copies full screen to clipboard | Detects clipboard image, saves it to `~/VaultyShot/` |
| `Cmd + Shift + Ctrl + 4` | Copies selection to clipboard | Detects clipboard image, saves it to `~/VaultyShot/` |

**Click the folder icon to access your screenshots:**

- Thumbnail preview for each screenshot
- Click to open in Preview
- Hover to reveal actions: **copy**, **reveal in Finder**, **delete**
- Screenshot count in the header
- "Open Folder" to jump to `~/VaultyShot/` in Finder

## How it works

```
┌─────────────────────────────────────────────────┐
│                   VaultyShot                    │
│                                                 │
│   ┌──────────────┐     ┌──────────────────┐     │
│   │ File Watcher │────▶│                  │     │
│   │  (FSEvents)  │     │   ~/VaultyShot/  │     │
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

- **File Watcher** — Monitors your screenshot directory (Desktop by default) using macOS FSEvents. When a new screenshot file appears, it moves it to `~/VaultyShot/`.
- **Clipboard Watcher** — Polls the system pasteboard every 0.8s. When a new image is copied via `Cmd+Shift+Ctrl`, it saves it as a PNG in `~/VaultyShot/`.
- **Popover UI** — SwiftUI view with async thumbnails (via QuickLookThumbnailing), hover actions, and quick access.

## Installation

### Homebrew (recommended)

```bash
brew tap nelahia/tap
brew install --cask vaultyshot
```

### Manual download

1. Download `VaultyShot.dmg` from the [latest release](https://github.com/Nelahia/vaulty-shot/releases/latest)
2. Open the disk image and drag `VaultyShot.app` to `/Applications`
3. Launch VaultyShot from Applications

Releases are **signed with a Developer ID Application certificate and notarized by Apple**, so the app opens with no Gatekeeper warning.

### Build from source

Requires macOS 14.0+, Xcode 16+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/Nelahia/vaulty-shot.git
cd vaulty-shot
brew install xcodegen
xcodegen generate
xcodebuild -project VaultyShot.xcodeproj \
  -scheme VaultyShot \
  -configuration Release \
  -derivedDataPath build
open build/Build/Products/Release/VaultyShot.app
```

### Launch at login (optional)

1. Open **System Settings** → **General** → **Login Items**
2. Click **+** and select `VaultyShot.app`

## Project structure

```
VaultyShot/
├── VaultyShotApp.swift            # Entry point, AppDelegate, NSStatusItem
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
└── VaultyShot.entitlements
```

## Tech stack

- **Swift 5.9** + **SwiftUI** + **AppKit**
- **FSEvents** via `DispatchSource` for file monitoring
- **NSPasteboard** polling for clipboard capture
- **QuickLookThumbnailing** for async thumbnail generation
- **No external dependencies**

## Release process

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds, signs with a
Developer ID Application certificate, notarizes, and packages the app as a `.dmg`. It
requires these GitHub repo secrets to be set (no values here, just names):

| Secret | Purpose |
|---|---|
| `APPLE_CERTIFICATE_P12_BASE64` | Base64 of the exported Developer ID Application `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Password protecting that `.p12` |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password from [appleid.apple.com](https://appleid.apple.com) |

After a release, bump `url`/`version`/`sha256` in the `vaultyshot` cask over in
`nelahia/homebrew-tap`.

## License

MIT
