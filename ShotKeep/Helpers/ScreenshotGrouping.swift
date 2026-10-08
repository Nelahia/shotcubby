import Foundation

enum ScreenshotGrouping {
    struct Section: Identifiable {
        let label: String
        let items: [ScreenshotItem]
        var id: String { label }
    }

    static func grouped(_ items: [ScreenshotItem], now: Date = Date(), calendar: Calendar = .current) -> [Section] {
        let buckets = Dictionary(grouping: items) { label(for: $0.createdAt, now: now, calendar: calendar) }
        return buckets
            .map { Section(label: $0.key, items: $0.value) }
            .sorted { lhs, rhs in
                let lhsDate = lhs.items.first?.createdAt ?? .distantPast
                let rhsDate = rhs.items.first?.createdAt ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    private static func label(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
