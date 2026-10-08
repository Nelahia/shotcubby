import SwiftUI

struct PermissionCardView: View {
    let screenshotDirectory: String
    let onOpenSettings: () -> Void
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusLine
            VStack(alignment: .leading, spacing: 6) {
                Text("Let ShotKeep read your screenshot folder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("TextPrimary"))
                Text("macOS needs your OK before ShotKeep can move new screenshots out of it. Nothing else in the folder is touched.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("TextSecondary"))
            }
            pathRow

            VStack(spacing: 8) {
                Button(action: onOpenSettings) {
                    Text("Open Privacy Settings")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onChooseFolder) {
                    Text("Use a different folder…")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("TextSecondary"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color("PanelBackground"), in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusLine: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color("WarningColor"))
                .frame(width: 7, height: 7)
            Text("Clipboard captures only")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color("WarningColor"))
        }
    }

    private var pathRow: some View {
        HStack(spacing: 6) {
            Text(shortened(screenshotDirectory))
            Image(systemName: "arrow.right")
                .foregroundStyle(Color.accentColor)
            Text("~/ShotKeep")
        }
        .font(.system(size: 12, design: .monospaced))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color("TextPrimary"))
        .background(Color("PopoverBackground"), in: RoundedRectangle(cornerRadius: 6))
    }

    private func shortened(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
