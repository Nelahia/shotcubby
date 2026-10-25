import SwiftUI

/// One Settings page: a title, a sentence under it, then its blocks.
struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(title)).font(.title2.weight(.semibold))
                    Text(LocalizedStringKey(subtitle))
                        .foregroundStyle(SettingsStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 4)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .background(SettingsStyle.window)
    }
}
