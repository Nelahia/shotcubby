import SwiftUI

/// The left column of the Settings window: the brand, then one row per pane.
struct SettingsSidebar: View {
    @Binding var selection: SettingsPane

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            brand
            ForEach(SettingsPane.allCases) { pane in
                row(pane)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(width: 208)
        .frame(maxHeight: .infinity)
        .background(SettingsStyle.surface.ignoresSafeArea())
    }

    private func row(_ pane: SettingsPane) -> some View {
        let selected = selection == pane
        return Button {
            selection = pane
        } label: {
            Label(pane.title, systemImage: pane.symbol)
                .fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(selected ? SettingsStyle.ink : SettingsStyle.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? SettingsStyle.raised : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ShotCubbyGlyph()
                .frame(width: 16, height: 16)
                .foregroundStyle(Color(hex: 0xDCE3EF))
                .frame(width: 26, height: 26)
                .background(Color(hex: 0x111522), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.white.opacity(0.14)))
            Text("ShotCubby").fontWeight(.semibold).foregroundStyle(SettingsStyle.ink)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}
