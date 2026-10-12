import SwiftUI

/// Bridges AppState to the value-based PopoverView API (see ShotBridge).
struct PopoverHost: View {
    @ObservedObject var appState: AppState
    let openSettings: () -> Void
    let openSpotlight: () -> Void

    var body: some View {
        PopoverView(
            shots: appState.screenshots.map(ShotBridge.toShot),
            accessFailure: appState.accessFailure,
            watchedFolder: URL(fileURLWithPath: appState.screenshotDirectory),
            keepFolder: appState.vaultURL,
            actions: ShotBridge.actions(for: appState, openSettings: openSettings, openSpotlight: openSpotlight)
        )
    }
}
