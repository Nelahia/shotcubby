import SwiftUI

/// The soft rounded button used across Settings (Save, Test, Reset…). With
/// `prominent` it is filled with `tint` (the accent, or the warning color in
/// an alert).
struct SettingsButtonStyle: ButtonStyle {
    var prominent = false
    var tint = SettingsStyle.accent

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(prominent ? Color.black.opacity(0.85) : Color.primary)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(fill(pressed: configuration.isPressed))
            )
            .opacity(isEnabled ? 1 : 0.5)
    }

    private func fill(pressed: Bool) -> Color {
        if prominent { return tint.opacity(pressed ? 0.8 : 1) }
        return Color.primary.opacity(pressed ? 0.16 : 0.09)
    }
}
