import SwiftUI

/// Settings block: where the screenshots live, with a button to move them.
struct VaultFolderSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Screenshots folder").fontWeight(.semibold)
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.title3)
                    .foregroundStyle(SettingsStyle.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text((appState.vaultURL.path as NSString).abbreviatingWithTildeInPath)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                    Text(ScreenshotStorage.summaryText(appState.screenshots))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Show in Finder") { appState.openVaultFolder() }
                    .buttonStyle(SettingsButtonStyle())
                Button("Move…") { appState.moveVault() }
                    .buttonStyle(SettingsButtonStyle(prominent: true))
            }
            .padding(12)
            .background(SettingsStyle.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("Pick a new location and ShotCubby moves your existing screenshots there, then saves new ones in it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
