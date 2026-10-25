import SwiftUI

/// The Light / Dark switch of Settings, drawn like the Windows one.
struct AppearancePicker: View {
    @Binding var selection: Appearance

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Appearance.allCases) { option in
                Button {
                    selection = option
                } label: {
                    Text(option.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(selection == option ? SettingsStyle.ink : SettingsStyle.muted)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selection == option ? SettingsStyle.raised : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(3)
        .background(SettingsStyle.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(SettingsStyle.hairline))
    }
}
