import SwiftUI

/// Bridges AppState to the value-based PopoverView API (see ShotBridge).
struct PopoverHost: View {
    @ObservedObject var appState: AppState
    let openSettings: () -> Void

    var body: some View {
        PopoverView(
            shots: appState.screenshots.map(ShotBridge.toShot),
            needsFolderAccess: appState.permissionDenied,
            watchedFolder: URL(fileURLWithPath: appState.screenshotDirectory),
            keepFolder: appState.vaultURL,
            actions: ShotBridge.actions(for: appState, openSettings: openSettings)
        )
        .onAppear { appState.retryScreenshotAccess() }
    }
}
