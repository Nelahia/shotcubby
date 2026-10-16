import Foundation

/// Turns a model's raw answer into a safe file name stem: first line only,
/// quotes dropped, file-name-hostile characters removed, whitespace collapsed,
/// length capped, then trailing punctuation dropped (after the cap, so a cut
/// can't leave one behind). May come out empty.
/// Mirrors `services/llm/title.rs` on Windows.
enum TitleCleaner {
    private static let maxLength = 80
    private static let quotes = CharacterSet(charactersIn: "\"'`«»“”‘’")
    private static let forbidden = CharacterSet(charactersIn: "\\/:*?\"<>|")
    private static let trailing = CharacterSet(charactersIn: ".!?,;:-").union(.whitespaces)

    static func clean(_ raw: String) -> String {
        let firstLine = raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        let unquoted = firstLine.trimmingCharacters(in: quotes)
        let safe = String(unquoted.unicodeScalars.filter { !forbidden.contains($0) })
        let collapsed = safe.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(collapsed.prefix(maxLength)).trimmingCharacters(in: trailing)
    }
}
