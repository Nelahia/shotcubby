use super::{i18n_fr::FRENCH, language};

/// The text in the app's language. The English text is the key: a text with no
/// French entry is shown in English, so nothing is ever blank.
pub fn tr(english: &str) -> String {
    if language::is_french()
        && let Some((_, french)) = FRENCH.iter().find(|(key, _)| *key == english)
    {
        return (*french).to_string();
    }
    english.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    #[test]
    fn every_english_key_is_listed_once() {
        let mut seen = HashSet::new();
        for (key, _) in FRENCH {
            assert!(seen.insert(*key), "duplicate key: {key}");
        }
    }

    #[test]
    fn no_translation_is_empty() {
        assert!(FRENCH.iter().all(|(_, french)| !french.is_empty()));
    }

    #[test]
    fn english_is_returned_as_is() {
        assert_eq!(tr("Quit ShotCubby"), "Quit ShotCubby");
    }
}
