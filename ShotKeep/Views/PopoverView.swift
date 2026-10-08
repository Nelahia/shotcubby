import SwiftUI

struct PopoverView: View {
    @ObservedObject var appState: AppState
    @State private var selectedFilter: ScreenshotFilter = .all

    private var filteredScreenshots: [ScreenshotItem] {
        appState.screenshots.filter(selectedFilter.matches)
    }

    private var sections: [ScreenshotGrouping.Section] {
        ScreenshotGrouping.grouped(filteredScreenshots)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            FilterBarView(screenshots: appState.screenshots, selection: $selectedFilter)
                .padding(.vertical, 10)
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(width: 360, height: 480)
        .background(Color("PopoverBackground"))
        .onAppear { appState.retryScreenshotAccess() }
    }

    private var headerView: some View {
        HStack {
            Image("MenuBarGlyph")
                .renderingMode(.template)
                .foregroundStyle(Color.accentColor)
            Text("ShotKeep")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("TextPrimary"))
            Spacer()
            Text("\(appState.screenshots.count)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color("TextSecondary"))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color("PanelBackground"), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if appState.permissionDenied {
                    PermissionCardView(
                        screenshotDirectory: appState.screenshotDirectory,
                        onOpenSettings: appState.openPrivacySettings,
                        onChooseFolder: appState.chooseCustomFolder
                    )
                    .padding(.horizontal, 14)
                }

                if filteredScreenshots.isEmpty {
                    EmptyStateView()
                } else {
                    ForEach(sections) { section in
                        ScreenshotGridSection(
                            section: section,
                            onOpen: { appState.openScreenshot($0) },
                            onCopy: { appState.copyToClipboard($0) },
                            onReveal: { appState.revealInFinder($0) },
                            onDelete: { appState.deleteScreenshot($0) }
                        )
                        .padding(.horizontal, 14)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var footerView: some View {
        HStack {
            Button(action: appState.openVaultFolder) {
                Label("Open Folder", systemImage: "folder")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color("TextSecondary"))
            .keyboardShortcut("o", modifiers: .command)

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                Label("Quit", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color("TextSecondary"))
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color("PanelBackground"))
    }
}
