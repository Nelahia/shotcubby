import SwiftUI

/// What the last smart-naming attempt did.
struct AIResultCard: View {
    let outcome: AIOutcome?

    private var failed: Bool { outcome?.isFailure ?? false }
    private var tint: Color { failed ? SettingsStyle.warn : SettingsStyle.accent }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: failed ? "exclamationmark.triangle" : "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("LAST RESULT")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                Text(outcome?.message ?? "Nothing yet — take a screenshot")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.22))
        )
    }
}
