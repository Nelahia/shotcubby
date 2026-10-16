import SwiftUI

/// "Key saved" pill with a cross that removes the key.
struct AIKeyChip: View {
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
            Text("Key saved").font(.caption.weight(.semibold))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Remove the saved key")
        }
        .foregroundStyle(SettingsStyle.accent)
        .padding(.leading, 11)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
        .background(SettingsStyle.accent.opacity(0.14), in: Capsule())
    }
}
