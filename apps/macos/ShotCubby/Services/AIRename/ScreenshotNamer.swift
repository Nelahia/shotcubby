import Foundation

/// Asks the chosen provider for a title of a screenshot. Only called once the
/// user has turned AI naming on; a failure means "keep the name" and is
/// recorded in `AIRenameStatus` so Settings can explain it.
enum ScreenshotNamer {
    /// Title for a capture that just landed in the vault.
    static func suggestedTitle(for url: URL) async throws -> String {
        let provider = AIRenamePreferences.provider
        guard let key = APIKeyStore.get(provider) else { throw AIFailure.other("No API key saved") }
        guard let jpeg = ImageDownscaler.jpeg(from: url) else {
            throw AIFailure.other(tr("Could not read the screenshot"))
        }
        let title = try await provider.title(
            apiKey: key, jpeg: jpeg, instructions: AIRenamePreferences.instructions
        )
        guard !title.isEmpty else { throw AIFailure.other(tr("The provider returned no title")) }
        return title
    }

    /// Sends a tiny generated picture with the saved key, so the user sees it works.
    static func testKey(for provider: LLMProvider) async throws {
        guard let key = APIKeyStore.get(provider) else { throw AIFailure.other("No key saved") }
        guard let jpeg = ImageDownscaler.sampleJPEG() else {
            throw AIFailure.other(tr("Could not build the test picture"))
        }
        _ = try await provider.title(apiKey: key, jpeg: jpeg)
    }
}
