import Combine
import Foundation

/// State and actions behind the AI naming pane, so the view only displays.
@MainActor
final class AIRenameSettingsModel: ObservableObject {
    enum Tone { case neutral, ok, bad }

    struct Note {
        var text: String
        var tone: Tone = .neutral
    }

    @Published var enabled = AIRenamePreferences.isEnabled {
        didSet { AIRenamePreferences.setEnabled(enabled) }
    }
    @Published var provider = AIRenamePreferences.provider {
        didSet {
            AIRenamePreferences.setProvider(provider)
            failure = nil
            showKeyState()
        }
    }
    @Published var instructions = AIRenamePreferences.instructions ?? "" {
        didSet {
            if instructions.count > AIRenamePreferences.maxInstructionsLength {
                instructions = String(instructions.prefix(AIRenamePreferences.maxInstructionsLength))
                return
            }
            AIRenamePreferences.setInstructions(instructions)
        }
    }
    @Published var keyInput = ""
    @Published private(set) var hasKey = false
    @Published private(set) var note = Note(text: "")
    @Published private(set) var busy = false
    /// The failure the alert card explains; `nil` once dismissed or fixed.
    @Published private(set) var failure: AIFailure?
    @Published private(set) var last: AIOutcome?

    private var alerted: String?
    private var subscriptions = Set<AnyCancellable>()

    init() {
        showKeyState()
        AIRenameStatus.shared.$last
            .sink { [weak self] in self?.follow($0) }
            .store(in: &subscriptions)
    }

    func save() {
        do {
            try APIKeyStore.set(keyInput, for: provider)
            failure = nil
            showKeyState(tr("Key saved. Press Test to check it works."), tone: .ok)
        } catch {
            note = Note(text: error.localizedDescription, tone: .bad)
        }
    }

    func remove() {
        APIKeyStore.delete(provider)
        failure = nil
        showKeyState(tr("Key removed."), tone: .ok)
    }

    func test() async {
        busy = true
        note = Note(text: tr("Testing the key with the provider…"))
        do {
            try await ScreenshotNamer.testKey(for: provider)
            failure = nil
            note = Note(text: tr("The key works. New screenshots will be renamed."), tone: .ok)
        } catch {
            let found = (error as? AIFailure) ?? .other(error.localizedDescription)
            note = Note(text: found.message, tone: .bad)
            failure = found
        }
        busy = false
    }

    func dismissAlert() {
        failure = nil
    }

    /// A new background failure also opens the alert, once per distinct failure.
    private func follow(_ outcome: AIOutcome?) {
        last = outcome
        guard let found = outcome?.failure, found.message != alerted else { return }
        alerted = found.message
        failure = found
    }

    private func showKeyState(_ message: String? = nil, tone: Tone = .neutral) {
        keyInput = ""
        hasKey = APIKeyStore.has(provider)
        note = Note(
            text: message ?? tr("Stored in your Keychain. It only leaves this Mac to call your provider."),
            tone: tone
        )
    }
}
