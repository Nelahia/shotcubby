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
                .frame(width: 24, height: 24)
                .foregroundStyle(Color(hex: 0xDCE3EF))
                .frame(width: 36, height: 36)
                .background(Color(hex: 0x303D59), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("ShotCubby").fontWeight(.semibold).foregroundStyle(SettingsStyle.ink)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 40)
        .padding(.bottom, 14)
    }
}
