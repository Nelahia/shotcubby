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
                .foregroundStyle(Color(red: 0.957, green: 0.984, blue: 0.988))
                .frame(width: 26, height: 26)
                .background(Color(red: 0.047, green: 0.071, blue: 0.086), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.white.opacity(0.14)))
            Text("ShotCubby").fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}
