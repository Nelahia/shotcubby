import SwiftUI

struct ScreenshotsSettingsPane: View {
    @ObservedObject var appState: AppState
    @State private var organizeByDay = OrganizePreferences.organizeByDay

    var body: some View {
        SettingsPage(title: "Screenshots", subtitle: "Where your screenshots live, and how they are filed.") {
            SettingsCard {
                VaultFolderSection(appState: appState)
                Divider()
                SettingsRow(
                    title: "File past days into dated folders",
                    subtitle: "Today's screenshots stay in the main folder; older ones move to YYYY-MM-DD."
                ) {
                    Toggle("", isOn: $organizeByDay).labelsHidden().toggleStyle(.switch).tint(SettingsStyle.accent)
                }
            }
        }
        .onChange(of: organizeByDay) { _, on in OrganizePreferences.set(on) }
    }
}
