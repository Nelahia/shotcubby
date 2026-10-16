use crate::services::storage;

const MAX_CHARS: usize = 80;
const TRAILING: [char; 7] = ['.', '!', '?', ',', ';', ':', '-'];
/// Names Windows reserves for devices: a file cannot be called like this.
const RESERVED: [&str; 4] = ["con", "prn", "aux", "nul"];

/// Turns a model's raw answer into a safe file name stem: first line only,
/// quotes dropped, invalid file name characters removed, whitespace
/// collapsed, length capped, trailing punctuation dropped (after the cap, so
/// a cut can't leave one behind), reserved device names told apart. May come
/// out empty.
pub fn clean_title(raw: &str) -> String {
    let first_line = raw.lines().map(str::trim).find(|l| !l.is_empty()).unwrap_or("");
    let unquoted = first_line.trim_matches(|c: char| "\"'`«»“”‘’".contains(c));
    let safe = storage::sanitize(unquoted);
    let collapsed = safe.split_whitespace().collect::<Vec<_>>().join(" ");
    let capped: String = collapsed.chars().take(MAX_CHARS).collect();
    let title = capped.trim_end_matches(|c: char| TRAILING.contains(&c) || c.is_whitespace());
    if is_reserved(title) {
        format!("{title} image")
    } else {
        title.to_string()
    }
}

/// `CON`, `NUL`, `COM1`…`COM9`, `LPT1`…`LPT9`, with any extension, in any case.
fn is_reserved(name: &str) -> bool {
    let stem = name.split('.').next().unwrap_or("").to_lowercase();
    RESERVED.contains(&stem.as_str())
        || ["com", "lpt"]
            .iter()
            .any(|prefix| stem.strip_prefix(prefix).is_some_and(|n| matches!(n.as_bytes(), [b'1'..=b'9'])))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_quotes_and_final_punctuation() {
        assert_eq!(clean_title("\"Invoice for March.\""), "Invoice for March");
    }

    #[test]
    fn keeps_only_the_first_line() {
        assert_eq!(clean_title("\n Settings page\nIt shows toggles"), "Settings page");
    }

    #[test]
    fn removes_characters_windows_forbids() {
        assert_eq!(clean_title("a/b: c*d?"), "ab cd");
    }

    #[test]
    fn caps_the_length() {
        assert!(clean_title(&"word ".repeat(40)).chars().count() <= 80);
    }

    #[test]
    fn a_cut_never_leaves_trailing_punctuation() {
        let long = format!("{}-tail", "a".repeat(79));
        assert_eq!(clean_title(&long), "a".repeat(79));
    }

    #[test]
    fn reserved_device_names_are_made_usable() {
        assert_eq!(clean_title("CON"), "CON image");
        assert_eq!(clean_title("com3"), "com3 image");
        assert_eq!(clean_title("Console"), "Console");
    }

    #[test]
    fn empty_answer_gives_empty_title() {
        assert_eq!(clean_title("  \n "), "");
    }
}
