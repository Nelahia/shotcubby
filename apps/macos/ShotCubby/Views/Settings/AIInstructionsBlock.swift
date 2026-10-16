import SwiftUI

/// Free-text naming convention sent to the model with every screenshot.
struct AIInstructionsBlock: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Naming instructions").fontWeight(.semibold)
                Text("Optional").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(text.count)/\(AIRenamePreferences.maxInstructionsLength)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 84)
                .background(SettingsStyle.fieldBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(SettingsStyle.hairline))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("e.g. lowercase kebab-case, start with the app name, in English")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
            Text("Tell the AI how you want screenshots named. These instructions win over its defaults: length, language, format, a date prefix…")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}
