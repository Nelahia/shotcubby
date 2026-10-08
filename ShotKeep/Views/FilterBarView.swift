import SwiftUI

enum ScreenshotFilter: CaseIterable {
    case all
    case files
    case clipboard

    var title: String {
        switch self {
        case .all: "All"
        case .files: "Files"
        case .clipboard: "Clipboard"
        }
    }

    func matches(_ item: ScreenshotItem) -> Bool {
        switch self {
        case .all: true
        case .files: item.source == .file
        case .clipboard: item.source == .clipboard
        }
    }
}

struct FilterBarView: View {
    let screenshots: [ScreenshotItem]
    @Binding var selection: ScreenshotFilter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ScreenshotFilter.allCases, id: \.self) { filter in
                segment(filter)
            }
        }
        .padding(.horizontal, 14)
    }

    private func segment(_ filter: ScreenshotFilter) -> some View {
        let count = screenshots.filter(filter.matches).count
        let isSelected = selection == filter

        return Button { selection = filter } label: {
            HStack(spacing: 4) {
                Text(filter.title)
                Text("\(count)")
                    .font(.system(size: 10, design: .monospaced))
                    .opacity(0.7)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .foregroundStyle(isSelected ? Color("TextOnAccent") : Color("TextPrimary"))
            .background(
                isSelected ? Color.accentColor : Color("PanelBackground"),
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
    }
}
