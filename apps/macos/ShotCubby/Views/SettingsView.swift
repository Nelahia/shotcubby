import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var pane: SettingsPane = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { pane in
                Label(pane.title, systemImage: pane.symbol).tag(pane)
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            switch pane {
            case .general: GeneralSettingsPane()
            case .screenshots: ScreenshotsSettingsPane(appState: appState)
            case .shortcuts: ShortcutsSettingsPane()
            }
        }
        .frame(width: 720, height: 460)
    }
}
