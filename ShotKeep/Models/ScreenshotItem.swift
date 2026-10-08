import Foundation

struct ScreenshotItem: Identifiable, Equatable {
    let id: String
    let url: URL
    let name: String
    let createdAt: Date

    init(url: URL) {
        self.id = url.lastPathComponent
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
    }
}
