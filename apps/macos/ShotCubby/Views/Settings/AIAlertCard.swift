import SwiftUI

/// A dismissible card explaining why a provider call failed and how to fix it.
struct AIAlertCard: View {
    let failure: AIFailure
    let provider: LLMProvider
    let onDismiss: () -> Void

    var body: some View {
        let copy = AIAlertCopy.make(for: failure, provider: provider)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SettingsStyle.warn)
                    .frame(width: 36, height: 36)
                    .background(SettingsStyle.warn.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.title).font(.headline).foregroundStyle(SettingsStyle.warn)
                    Text(LocalizedStringKey(copy.body)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }

            if !copy.steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(copy.steps.enumerated()), id: \.offset) { index, step in
                        // One String, not an interpolated literal: interpolated
                        // values are not parsed as Markdown, which would show the ** as is.
                        Text(LocalizedStringKey(String(index + 1) + ". " + step)).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 10) {
                if let action = copy.action {
                    Button {
                        NSWorkspace.shared.open(action.url)
                    } label: {
                        Label(action.label, systemImage: "arrow.up.right")
                    }
                    .buttonStyle(SettingsButtonStyle(prominent: true, tint: SettingsStyle.warn))
                }
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsStyle.warn.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SettingsStyle.warn.opacity(0.38))
        )
    }
}
