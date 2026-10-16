const BASE: &str = "Name this screenshot for use as a file name. \
Reply with ONLY a title of 3 to 6 words, in the language of the text visible in it, \
saying what it shows (app, page or subject). No quotes, no final punctuation, no extension.";

/// What the model is asked. The user's own naming instructions, when there
/// are any, win over the defaults wherever they conflict. Mirrors
/// `LLMProvider.prompt` on macOS.
pub fn build(instructions: Option<&str>, today: &str) -> String {
    let Some(instructions) = instructions.map(str::trim).filter(|text| !text.is_empty()) else {
        return BASE.to_string();
    };
    format!(
        "{BASE}\n\nThe user's own naming instructions follow. They take precedence over the defaults \
above whenever they conflict (length, language, format...). Still reply with ONLY the file name, \
without extension.\n<instructions>\n{instructions}\n</instructions>\nToday's date is {today}."
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn without_instructions_the_default_prompt_is_unchanged() {
        assert_eq!(build(None, "2026-10-16"), BASE);
        assert_eq!(build(Some("   "), "2026-10-16"), BASE);
    }

    #[test]
    fn instructions_are_added_and_win_over_the_defaults() {
        let prompt = build(Some("kebab-case, in English"), "2026-10-16");
        assert!(prompt.starts_with(BASE));
        assert!(prompt.contains("take precedence"));
        assert!(prompt.contains("<instructions>\nkebab-case, in English\n</instructions>"));
        assert!(prompt.contains("2026-10-16"));
    }
}
