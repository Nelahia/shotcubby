import SwiftUI

struct ScreenshotGridCell: View {
    let item: ScreenshotItem
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void

    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
            caption
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onHover { isHovered = $0 }
        .alert("Rename Screenshot", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { onRename(newName) }
        }
    }

    private var thumbnail: some View {
        AsyncThumbnail(url: item.url, targetSize: CGSize(width: 240, height: 180))
            .aspectRatio(4.0 / 3.0, contentMode: .fill)
            .background(Color("ThumbnailBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isHovered ? Color.accentColor : Color("SeparatorColor"),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            )
            .overlay { if isHovered { hoverVeil } }
    }

    private var hoverVeil: some View {
        ZStack {
            Color.black.opacity(0.55)
            HStack(spacing: 5) {
                RoundIconButton(symbol: "doc.on.doc", action: onCopy)
                RoundIconButton(symbol: "pencil", action: beginRenaming)
                RoundIconButton(symbol: "folder", action: onReveal)
                RoundIconButton(symbol: "trash", action: onDelete)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func beginRenaming() {
        newName = item.name
        isRenaming = true
    }

    private var caption: some View {
        HStack {
            Text(item.createdAt.formatted(date: .omitted, time: .shortened))
            Spacer()
            Text(item.sourceLabel)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Color("TextSecondary"))
        .lineLimit(1)
    }
}

private struct RoundIconButton: View {
    let symbol: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    isHovered ? Color.accentColor : Color.black.opacity(0.55),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
