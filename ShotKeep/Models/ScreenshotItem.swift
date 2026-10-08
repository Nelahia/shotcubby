import Foundation

struct ScreenshotItem: Identifiable, Equatable {
    enum Source {
        case file
        case clipboard
    }

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

    var source: Source {
        name.hasSuffix("(clipboard)") ? .clipboard : .file
    }

    var sourceLabel: String {
        switch source {
        case .file: url.pathExtension.uppercased()
        case .clipboard: "Clipboard"
        }
    }
}
