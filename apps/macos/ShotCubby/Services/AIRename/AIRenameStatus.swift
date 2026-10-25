import Foundation

/// What the last smart-naming attempt did, shown in Settings so a failure
/// (quota, network, a bad key) is never invisible. Mirrors `Outcome` in
/// `auto_rename.rs` on Windows.
struct AIOutcome: Equatable {
    let message: String
    /// Set when the attempt failed.
    let failure: AIFailure?

    var isFailure: Bool { failure != nil }
}

@MainActor
final class AIRenameStatus: ObservableObject {
    static let shared = AIRenameStatus()

    @Published private(set) var last: AIOutcome?

    func recordRenamed(_ title: String) {
        last = AIOutcome(message: String(format: tr("Renamed to “%@”"), title), failure: nil)
    }

    func record(_ error: Error) {
        let failure = (error as? AIFailure) ?? .other(error.localizedDescription)
        last = AIOutcome(message: failure.message, failure: failure)
    }
}
