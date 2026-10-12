import SwiftUI

struct GeneralSettingsPane: View {
    @State private var showInDock = DockPreferences.showInDock
    @State private var checksAutomatically = AppUpdater.shared.automaticallyChecks

    var body: some View {
        Form {
            Section {
                Toggle("Show in the Dock", isOn: $showInDock)
                Toggle("Check for updates automatically", isOn: $checksAutomatically)
                LabeledContent("Version \(Self.versionLabel)") {
                    Button("Check for Updates…") { AppUpdater.shared.checkForUpdates() }
                }
            } footer: {
                Text("Clicking the Dock icon opens the search panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: showInDock) { _, show in DockPreferences.set(show) }
        .onChange(of: checksAutomatically) { _, on in AppUpdater.shared.automaticallyChecks = on }
    }

    /// The release version stamped into Info.plist by the release workflow.
    private static var versionLabel: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
