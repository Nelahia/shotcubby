import SwiftUI

/// Bridges AppState (ObservableObject, ScreenshotItem) to the value-based
/// PopoverView API in ShotKeepPopover.swift (Shot, ShotActions). Actions are
/// wired through AppState rather than ShotActions.live(...) so the in-memory
/// `screenshots` array stays in sync with rename/delete — nothing else
/// watches the ~/ShotKeep vault folder itself for those changes.
struct PopoverHost: View {
    @ObservedObject var appState: AppState

    var body: some View {
        PopoverView(
            shots: appState.screenshots.map(Self.toShot),
            needsFolderAccess: appState.permissionDenied,
            watchedFolder: URL(fileURLWithPath: appState.screenshotDirectory),
            keepFolder: appState.vaultURL,
            actions: ShotActions(
                open: { find($0).map(appState.openScreenshot) },
                copy: { find($0).map(appState.copyToClipboard) },
                reveal: { find($0).map(appState.revealInFinder) },
                delete: { find($0).map(appState.deleteScreenshot) },
                rename: { shot, newName in
                    find(shot).map { appState.renameScreenshot($0, to: newName) }
                },
                openFolder: appState.openVaultFolder,
                openPrivacySettings: appState.openPrivacySettings,
                chooseFolder: appState.chooseCustomFolder,
                openSettings: {},
                quit: { NSApp.terminate(nil) }
            )
        )
        .onAppear { appState.retryScreenshotAccess() }
    }

    private func find(_ shot: Shot) -> ScreenshotItem? {
        appState.screenshots.first { $0.url == shot.url }
    }

    private static func toShot(_ item: ScreenshotItem) -> Shot {
        Shot(url: item.url, date: item.createdAt, source: item.source == .clipboard ? .clipboard : .file)
    }
}
