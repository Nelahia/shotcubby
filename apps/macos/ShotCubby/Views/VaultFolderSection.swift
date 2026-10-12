import SwiftUI

/// Settings block: where the screenshots live, with a button to move them.
struct VaultFolderSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text((appState.vaultURL.path as NSString).abbreviatingWithTildeInPath)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Text(ScreenshotStorage.summaryText(appState.screenshots))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack {
                Spacer()
                Button("Show in Finder") { appState.openVaultFolder() }
                Button("Move…") { appState.moveVault() }
                    .buttonStyle(.borderedProminent)
            }
        } header: {
            Text("Screenshots folder")
        } footer: {
            Text("Pick a new location and ShotCubby moves your existing screenshots there, then saves new ones in it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
