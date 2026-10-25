import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var pane: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $pane)
            Rectangle().fill(SettingsStyle.hairline).frame(width: 1).ignoresSafeArea()
            detail
        }
        .frame(width: 800, height: 560)
        .foregroundStyle(SettingsStyle.ink)
        .background(SettingsStyle.window.ignoresSafeArea())
    }

    @ViewBuilder private var detail: some View {
        switch pane {
        case .general: GeneralSettingsPane()
        case .screenshots: ScreenshotsSettingsPane(appState: appState)
        case .aiNaming: AIRenameSettingsPane()
        case .shortcuts: ShortcutsSettingsPane()
        }
    }
}
