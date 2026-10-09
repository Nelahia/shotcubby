import AppKit

/// Bridges AppState (ObservableObject, ScreenshotItem) to the value-based
/// Shot/ShotActions API shared by ShotKeepPopover.swift and
/// ShotKeepSpotlight.swift. Actions go through AppState's own methods
/// rather than ShotActions.live(...), so the in-memory `screenshots` array
/// stays in sync with rename/delete — nothing else watches the ~/ShotKeep
/// vault folder itself for those changes. Shared by PopoverHost and
/// AppDelegate's SpotlightController so both surfaces act on the same data.
enum ShotBridge {
    static func toShot(_ item: ScreenshotItem) -> Shot {
        Shot(url: item.url, date: item.createdAt, source: item.source == .clipboard ? .clipboard : .file)
    }

    static func actions(for appState: AppState, openSettings: @escaping () -> Void) -> ShotActions {
        ShotActions(
            open: { find($0, in: appState).map(appState.openScreenshot) },
            copy: { find($0, in: appState).map(appState.copyToClipboard) },
            reveal: { find($0, in: appState).map(appState.revealInFinder) },
            delete: { find($0, in: appState).map(appState.deleteScreenshot) },
            rename: { shot, newName in
                find(shot, in: appState).map { appState.renameScreenshot($0, to: newName) }
            },
            openFolder: appState.openVaultFolder,
            openPrivacySettings: appState.openPrivacySettings,
            chooseFolder: appState.chooseCustomFolder,
            openSettings: openSettings,
            quit: { NSApp.terminate(nil) }
        )
    }

    private static func find(_ shot: Shot, in appState: AppState) -> ScreenshotItem? {
        appState.screenshots.first { $0.url == shot.url }
    }
}
