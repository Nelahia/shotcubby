import Foundation

/// What each kind of failure means to the user, and what to do about it.
/// Text uses Markdown (`**bold**`). Mirrors `describe` in `ai-alert.js`.
struct AIAlertCopy {
    struct Action {
        let label: String
        let url: URL
    }

    let title: String
    let body: String
    var steps: [String] = []
    var action: Action?

    static func make(for failure: AIFailure, provider: LLMProvider) -> AIAlertCopy {
        let console = Console.of(provider)
        switch failure.kind {
        case .workspace:
            return AIAlertCopy(
                title: "This key isn’t tied to a workspace",
                body: "Anthropic only accepts API keys created **inside a workspace**. The key you pasted works at the account level, so every request is refused.",
                steps: [
                    "Open the **API keys** page of the Claude Console.",
                    "Create a key and pick a workspace (the **Default** one is fine).",
                    "Paste the new key below and press **Test**.",
                ],
                action: Action(label: "Open Claude Console", url: console.keys)
            )
        case .rejected:
            return AIAlertCopy(
                title: "The provider refused this key",
                body: "The key is wrong, was revoked, or was copied incompletely. Paste it again, or create a new one.",
                action: Action(label: String(format: tr("Open %@"), console.name), url: console.keys)
            )
        case .credit:
            return AIAlertCopy(
                title: "No credit left on this account",
                body: "API usage is billed separately from a Claude or ChatGPT subscription. Add credit, then try again. A screenshot costs a fraction of a cent.",
                action: Action(label: "Open billing", url: console.billing)
            )
        case .rateLimit:
            return AIAlertCopy(
                title: "Too many requests",
                body: "The provider is limiting this key for a moment. AI naming will work again shortly."
            )
        case .network:
            return AIAlertCopy(
                title: "Can’t reach the provider",
                body: "Check your internet connection. Screenshots keep their current names until it is back."
            )
        case .other:
            return AIAlertCopy(title: "AI naming didn’t work", body: failure.message)
        }
    }

    private struct Console {
        let name: String
        let keys: URL
        let billing: URL

        static func of(_ provider: LLMProvider) -> Console {
            switch provider {
            case .anthropic:
                return Console(
                    name: "Claude Console",
                    keys: URL(string: "https://platform.claude.com/settings/keys")!,
                    billing: URL(string: "https://platform.claude.com/settings/billing")!
                )
            case .openai:
                return Console(
                    name: "OpenAI platform",
                    keys: URL(string: "https://platform.openai.com/api-keys")!,
                    billing: URL(string: "https://platform.openai.com/settings/organization/billing")!
                )
            }
        }
    }
}
