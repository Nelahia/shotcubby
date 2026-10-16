import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var pane: SettingsPane = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { pane in
                Label(pane.title, systemImage: pane.symbol).tag(pane)
            }
            .safeAreaInset(edge: .top, spacing: 0) { brand }
            .navigationSplitViewColumnWidth(208)
        } detail: {
            switch pane {
            case .general: GeneralSettingsPane()
            case .screenshots: ScreenshotsSettingsPane(appState: appState)
            case .aiNaming: AIRenameSettingsPane()
            case .shortcuts: ShortcutsSettingsPane()
            }
        }
        .frame(width: 800, height: 560)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ShotCubbyGlyph()
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.black.opacity(0.85))
                .frame(width: 26, height: 26)
                .background(SettingsStyle.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text("ShotCubby").fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}
