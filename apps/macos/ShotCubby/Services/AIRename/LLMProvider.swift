import Foundation

/// The providers AI naming can talk to. The user brings their own key;
/// nothing is sent until they turn AI naming on and save one. Mirrors
/// `services/llm/mod.rs` on Windows.
enum LLMProvider: String, CaseIterable, Identifiable {
    case anthropic, openai

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anthropic: "Anthropic (Claude)"
        case .openai: "OpenAI"
        }
    }

    var shortLabel: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        }
    }

    private static let basePrompt = "Name this screenshot for use as a file name. "
        + "Reply with ONLY a title of 3 to 6 words, in the language of the text visible in it, "
        + "saying what it shows (app, page or subject). No quotes, no final punctuation, no extension."

    /// What the model is asked. The user's own naming instructions, when
    /// there are any, win over the defaults wherever they conflict.
    static func prompt(instructions: String?) -> String {
        guard let instructions, !instructions.isEmpty else { return basePrompt }
        let today = Date.now.formatted(.iso8601.year().month().day())
        return basePrompt
            + "\n\nThe user's own naming instructions follow. They take precedence over the defaults above "
            + "whenever they conflict (length, language, format...). Still reply with ONLY the file name, "
            + "without extension.\n<instructions>\n\(instructions)\n</instructions>\nToday's date is \(today)."
    }

    func title(apiKey: String, jpeg: Data, instructions: String? = nil) async throws -> String {
        let prompt = Self.prompt(instructions: instructions)
        let raw: String
        switch self {
        case .anthropic: raw = try await AnthropicClient.request(apiKey: apiKey, jpeg: jpeg, prompt: prompt)
        case .openai: raw = try await OpenAIClient.request(apiKey: apiKey, jpeg: jpeg, prompt: prompt)
        }
        return TitleCleaner.clean(raw)
    }
}
