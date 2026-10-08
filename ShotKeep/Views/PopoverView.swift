import SwiftUI

struct PopoverView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(width: 320, height: 480)
        .onAppear { appState.retryScreenshotAccess() }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)
                .font(.title3)
            Text("ShotKeep")
                .font(.headline)
            Spacer()
            Text("\(appState.screenshots.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var contentView: some View {
        Group {
            if appState.permissionDenied {
                permissionBanner
            }
            if appState.screenshots.isEmpty {
                EmptyStateView()
            } else {
                screenshotList
            }
        }
    }

    private var permissionBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("ShotKeep needs access to your screenshot folder")
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
            Text(appState.screenshotDirectory)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Open Privacy Settings") {
                    appState.openPrivacySettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Try Again") {
                    appState.retryScreenshotAccess()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var screenshotList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(appState.screenshots) { item in
                    ScreenshotRow(
                        item: item,
                        onOpen: { appState.openScreenshot(item) },
                        onCopy: { appState.copyToClipboard(item) },
                        onReveal: { appState.revealInFinder(item) },
                        onDelete: { appState.deleteScreenshot(item) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var footerView: some View {
        HStack {
            Button(action: appState.openVaultFolder) {
                Label("Open Folder", systemImage: "folder")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                Label("Quit", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
