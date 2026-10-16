import Foundation

extension AppState {
    /// AI naming for a capture that just landed in the vault. The capture
    /// shows up at once; the title arrives later and any failure leaves the
    /// name as is, noted in `AIRenameStatus` for Settings. A manual rename (or
    /// a day-folder move) while the request is in flight changes the item's
    /// id, so the late answer finds nothing to rename.
    func nameWithAI(_ item: ScreenshotItem) {
        guard AIRenamePreferences.isEnabled else { return }
        Task { [weak self] in
            do {
                let title = try await ScreenshotNamer.suggestedTitle(for: item.url)
                await MainActor.run {
                    guard let self, let current = self.screenshots.first(where: { $0.id == item.id }) else { return }
                    self.renameScreenshot(current, to: title)
                    AIRenameStatus.shared.recordRenamed(title)
                }
            } catch {
                await MainActor.run { AIRenameStatus.shared.record(error) }
            }
        }
    }
}
