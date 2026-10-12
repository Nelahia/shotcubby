# ShotCubby for macOS

The native macOS menu-bar app, written in Swift with SwiftUI and AppKit.
For what ShotCubby does, see the [main README](../../README.md).

## Requirements

- macOS 14+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Run in development

The Xcode project is generated from `project.yml` and never committed:

```bash
cd apps/macos
xcodegen generate
open ShotCubby.xcodeproj
```

Local builds are signed ad hoc; the release workflow signs and notarizes them
with the maintainer's Developer ID.

## Project layout

```
apps/macos/
├── project.yml          XcodeGen spec: targets, Info.plist keys, Sparkle package
└── ShotCubby/
    ├── ShotCubbyApp.swift   entry point, menu bar item
    ├── AppState.swift       shared observable state
    ├── Models/              ScreenshotItem, SpotlightCommand
    ├── Services/            watchers, storage, preferences, updater — all the logic
    └── Views/               popover, Spotlight-style search, settings
```
