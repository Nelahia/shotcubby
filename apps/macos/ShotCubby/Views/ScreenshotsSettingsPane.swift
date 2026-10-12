import SwiftUI

struct ScreenshotsSettingsPane: View {
    @ObservedObject var appState: AppState
    @State private var organizeByDay = OrganizePreferences.organizeByDay

    var body: some View {
        Form {
            VaultFolderSection(appState: appState)

            Section {
                Toggle("File past days into dated folders", isOn: $organizeByDay)
            } footer: {
                Text("Keeps today's screenshots in the main folder and moves older ones into YYYY-MM-DD folders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: organizeByDay) { _, on in OrganizePreferences.set(on) }
    }
}
