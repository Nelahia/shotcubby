import Foundation

/// AI naming is off until the user turns it on in Settings: nothing leaves
/// the machine by default. Mirrors `ai_rename_preferences.rs`.
enum AIRenamePreferences {
    private static let enabledKey = "aiRenameEnabled"
    private static let providerKey = "aiRenameProvider"
    private static let instructionsKey = "aiRenameInstructions"

    /// Longest naming instruction kept, so a paste can't bloat every request.
    static let maxInstructionsLength = 500

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: enabledKey)
    }

    static var provider: LLMProvider {
        UserDefaults.standard.string(forKey: providerKey).flatMap(LLMProvider.init(rawValue:)) ?? .anthropic
    }

    static func setProvider(_ provider: LLMProvider) {
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
    }

    /// The user's own naming convention, or `nil` when there is none.
    static var instructions: String? {
        let text = UserDefaults.standard.string(forKey: instructionsKey) ?? ""
        return text.isEmpty ? nil : text
    }

    static func setInstructions(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(String(trimmed.prefix(maxInstructionsLength)), forKey: instructionsKey)
    }
}
