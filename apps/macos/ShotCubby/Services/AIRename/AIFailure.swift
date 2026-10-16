import Foundation

/// Why a provider call failed. `kind` lets Settings explain the cause and the
/// fix in plain words; `message` is the short technical line. Neither ever
/// contains the key. Mirrors `services/llm/failure.rs` on Windows.
struct AIFailure: LocalizedError, Equatable {
    enum Kind: Equatable {
        /// The Anthropic key is not tied to a workspace.
        case workspace, rejected, credit, rateLimit, network, other
    }

    let kind: Kind
    let message: String

    var errorDescription: String? { message }

    static func other(_ message: String) -> AIFailure {
        AIFailure(kind: .other, message: message)
    }

    static func network(_ provider: String) -> AIFailure {
        AIFailure(kind: .network, message: "Could not reach \(provider)")
    }

    /// Sorts a non-200 answer by what the provider said, since the same HTTP
    /// status (400) covers a missing workspace and an empty balance alike.
    static func fromStatus(_ status: Int, detail: String?) -> AIFailure {
        let lowered = (detail ?? "").lowercased()
        if lowered.contains("workspace") {
            return AIFailure(kind: .workspace, message: "This API key is not scoped to a workspace")
        }
        if lowered.contains("credit balance") || lowered.contains("billing") || lowered.contains("quota") {
            return AIFailure(kind: .credit, message: "The account has no credit left")
        }
        switch status {
        case 401, 403: return AIFailure(kind: .rejected, message: "The API key was rejected")
        case 429: return AIFailure(kind: .rateLimit, message: "Too many requests, try again in a moment")
        default:
            let suffix = detail.map { ": \($0)" } ?? ""
            return .other("The provider answered with HTTP \(status)\(suffix)")
        }
    }
}
