import SwiftUI

struct GeneralSettingsPane: View {
    @State private var showInDock = DockPreferences.showInDock
    @State private var checksAutomatically = AppUpdater.shared.automaticallyChecks

    var body: some View {
        SettingsPage(title: "General", subtitle: "The Dock, updates, and the version you are running.") {
            SettingsCard {
                SettingsRow(title: "Show in the Dock", subtitle: "Clicking the Dock icon opens the search panel.") {
                    Toggle("", isOn: $showInDock).labelsHidden().toggleStyle(.switch).tint(SettingsStyle.accent)
                }
                Divider()
                SettingsRow(title: "Check for updates automatically") {
                    Toggle("", isOn: $checksAutomatically).labelsHidden().toggleStyle(.switch).tint(SettingsStyle.accent)
                }
                Divider()
                SettingsRow(title: "Version \(Self.versionLabel)") {
                    Button("Check for Updates…") { AppUpdater.shared.checkForUpdates() }
                        .buttonStyle(SettingsButtonStyle())
                }
            }
        }
        .onChange(of: showInDock) { _, show in DockPreferences.set(show) }
        .onChange(of: checksAutomatically) { _, on in AppUpdater.shared.automaticallyChecks = on }
    }

    /// The release version stamped into Info.plist by the release workflow.
    private static var versionLabel: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
