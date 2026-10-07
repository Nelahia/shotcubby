import SwiftUI
import QuickLookThumbnailing

struct AsyncThumbnail: View {
    let url: URL
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .task(id: url) { await loadThumbnail() }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
            }
    }

    private func loadThumbnail() async {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 88, height: 88),
            scale: 2.0,
            representationTypes: .thumbnail
        )

        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(
            for: request
        ) else { return }

        await MainActor.run {
            thumbnail = representation.nsImage
        }
    }
}
