use super::config_store;
use super::llm::Provider;

/// Longest naming instruction kept, so a paste can't bloat every request.
pub const MAX_INSTRUCTIONS: usize = 500;

/// Everything AI naming reads, from one load of the config. AI naming is off
/// until the user turns it on in Settings: nothing leaves the machine by
/// default. Mirrors `AIRenamePreferences.swift`.
pub struct Preferences {
    pub enabled: bool,
    pub provider: Provider,
    /// The user's own naming convention, or `None` when there is none.
    pub instructions: Option<String>,
}

pub fn load() -> Preferences {
    let config = config_store::load();
    Preferences {
        enabled: config.ai_rename_enabled,
        provider: config
            .ai_rename_provider
            .as_deref()
            .and_then(Provider::from_id)
            .unwrap_or(Provider::Anthropic),
        instructions: config.ai_rename_instructions.filter(|text| !text.is_empty()),
    }
}

pub fn set_enabled(enabled: bool) {
    config_store::update(|config| config.ai_rename_enabled = enabled);
}

pub fn set_provider(provider: Provider) {
    config_store::update(|config| config.ai_rename_provider = Some(provider.id().to_string()));
}

pub fn set_instructions(text: &str) {
    let trimmed: String = text.trim().chars().take(MAX_INSTRUCTIONS).collect();
    config_store::update(|config| config.ai_rename_instructions = (!trimmed.is_empty()).then_some(trimmed));
}
