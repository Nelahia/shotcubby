use crate::services::i18n::tr;
use super::llm::Provider;

const SERVICE: &str = "ShotCubby";

/// API keys live in the Windows Credential Manager, never in `config.json`.
/// Mirrors `APIKeyStore.swift` (Keychain on macOS).
fn entry(provider: Provider) -> Result<keyring::Entry, String> {
    keyring::Entry::new(SERVICE, &format!("{}-api-key", provider.id()))
        .map_err(|_| tr("The credential store is unavailable"))
}

pub fn get(provider: Provider) -> Option<String> {
    entry(provider).ok()?.get_password().ok().filter(|key| !key.is_empty())
}

pub fn has(provider: Provider) -> bool {
    get(provider).is_some()
}

pub fn set(provider: Provider, key: &str) -> Result<(), String> {
    let key = key.trim();
    if key.is_empty() {
        return Err(tr("The key is empty"));
    }
    entry(provider)?
        .set_password(key)
        .map_err(|_| tr("Could not save the key"))
}

pub fn delete(provider: Provider) {
    if let Ok(entry) = entry(provider) {
        let _ = entry.delete_credential();
    }
}
