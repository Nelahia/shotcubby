import SwiftUI

struct AIRenameSettingsPane: View {
    @StateObject private var model = AIRenameSettingsModel()

    var body: some View {
        SettingsPage(
            title: "AI naming",
            subtitle: "New screenshots are renamed after what they show, using your own AI key. Nothing is sent while this is off."
        ) {
            if let failure = model.failure {
                AIAlertCard(failure: failure, provider: model.provider, onDismiss: model.dismissAlert)
            }

            SettingsCard {
                SettingsRow(title: "Name new screenshots with AI", subtitle: "A downscaled copy of each capture goes to your provider.") {
                    Toggle("", isOn: $model.enabled).labelsHidden().toggleStyle(.switch).tint(SettingsStyle.accent)
                }
                Divider()
                SettingsRow(title: "Provider") {
                    Picker("Provider", selection: $model.provider) {
                        ForEach(LLMProvider.allCases) { Text($0.shortLabel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 190)
                }
                Divider()
                keyBlock
                Divider()
                AIInstructionsBlock(text: $model.instructions)
            }

            AIResultCard(outcome: model.last)
        }
    }

    private var keyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("API key").fontWeight(.semibold)
                Spacer()
                if model.hasKey { AIKeyChip(onRemove: model.remove).disabled(model.busy) }
            }
            HStack(spacing: 8) {
                SecureField("", text: $model.keyInput, prompt: Text(model.hasKey ? "Paste a new key to replace it" : "Paste your API key"))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(SettingsStyle.fieldBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(SettingsStyle.hairline))
                    .onSubmit { model.save() }
                Button("Save") { model.save() }
                    .buttonStyle(SettingsButtonStyle())
                    .disabled(model.keyInput.isEmpty || model.busy)
                if model.hasKey {
                    Button("Test") { Task { await model.test() } }
                        .buttonStyle(SettingsButtonStyle())
                        .disabled(model.busy)
                }
            }
            Label(model.note.text, systemImage: "lock")
                .font(.caption)
                .foregroundStyle(noteColor)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var noteColor: Color {
        switch model.note.tone {
        case .neutral: .secondary
        case .ok: SettingsStyle.accent
        case .bad: SettingsStyle.warn
        }
    }
}
