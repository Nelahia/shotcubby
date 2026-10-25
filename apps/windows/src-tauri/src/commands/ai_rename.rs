use crate::services::i18n::tr;
use serde::Serialize;

use crate::services::llm::{self, Failure, PROVIDERS, Provider, ProviderInfo};
use crate::services::{ai_rename_preferences, api_key_store, auto_rename};

#[derive(Serialize)]
pub struct AiRenameState {
    enabled: bool,
    provider: &'static str,
    has_key: bool,
    providers: &'static [ProviderInfo],
    instructions: String,
    last_result: Option<auto_rename::Outcome>,
}

fn parse(provider: &str) -> Result<Provider, String> {
    Provider::from_id(provider).ok_or_else(|| tr("Unknown provider"))
}

#[tauri::command]
pub fn get_ai_rename() -> AiRenameState {
    let preferences = ai_rename_preferences::load();
    AiRenameState {
        enabled: preferences.enabled,
        provider: preferences.provider.id(),
        has_key: api_key_store::has(preferences.provider),
        providers: &PROVIDERS,
        instructions: preferences.instructions.unwrap_or_default(),
        last_result: auto_rename::last_result(),
    }
}

/// Just the last attempt, for the page's refresh: no config or credential read.
#[tauri::command]
pub fn get_ai_last_result() -> Option<auto_rename::Outcome> {
    auto_rename::last_result()
}

#[tauri::command]
pub fn set_ai_rename_enabled(enabled: bool) {
    ai_rename_preferences::set_enabled(enabled);
}

#[tauri::command]
pub fn set_ai_rename_provider(provider: String) -> Result<bool, String> {
    let provider = parse(&provider)?;
    ai_rename_preferences::set_provider(provider);
    Ok(api_key_store::has(provider))
}

#[tauri::command]
pub fn save_api_key(provider: String, key: String) -> Result<(), String> {
    api_key_store::set(parse(&provider)?, &key)
}

#[tauri::command]
pub fn delete_api_key(provider: String) -> Result<(), String> {
    api_key_store::delete(parse(&provider)?);
    Ok(())
}

/// Sends a tiny generated picture with the saved key and returns the title
/// the provider gave, so the user sees the key works.
#[tauri::command]
pub async fn test_api_key(provider: String) -> Result<String, Failure> {
    let provider = Provider::from_id(&provider).ok_or_else(|| Failure::other(tr("Unknown provider")))?;
    let key = api_key_store::get(provider).ok_or_else(|| Failure::other("No key saved"))?;
    tauri::async_runtime::spawn_blocking(move || {
        let jpeg = llm::sample_jpeg().ok_or_else(|| Failure::other(tr("Could not build the test picture")))?;
        provider.title_for(&key, &jpeg, None)
    })
    .await
    .map_err(|_| Failure::other(tr("The test was interrupted")))?
}

#[tauri::command]
pub fn set_ai_rename_instructions(instructions: String) {
    ai_rename_preferences::set_instructions(&instructions);
}
