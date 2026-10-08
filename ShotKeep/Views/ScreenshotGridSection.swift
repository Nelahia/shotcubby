import SwiftUI

struct ScreenshotGridSection: View {
    let section: ScreenshotGrouping.Section
    let onOpen: (ScreenshotItem) -> Void
    let onCopy: (ScreenshotItem) -> Void
    let onReveal: (ScreenshotItem) -> Void
    let onDelete: (ScreenshotItem) -> Void
    let onRename: (ScreenshotItem, String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color("TextSecondary"))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(section.items) { item in
                    ScreenshotGridCell(
                        item: item,
                        onOpen: { onOpen(item) },
                        onCopy: { onCopy(item) },
                        onReveal: { onReveal(item) },
                        onDelete: { onDelete(item) },
                        onRename: { onRename(item, $0) }
                    )
                }
            }
        }
    }
}
