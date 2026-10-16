mod anthropic;
mod failure;
mod image_prep;
mod openai;
mod prompt;
mod title;

pub use failure::{Failure, Kind};
pub use image_prep::{prepare_jpeg, sample_jpeg};
pub use title::clean_title;

use base64::Engine;
use serde::Serialize;
use std::time::Duration;

/// Mirrors `LLMProvider.swift`. The user brings their own key; nothing is
/// sent to a provider until they turn AI naming on and save one.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Provider {
    Anthropic,
    OpenAi,
}

#[derive(Serialize)]
pub struct ProviderInfo {
    pub id: &'static str,
    pub label: &'static str,
}

pub const PROVIDERS: [ProviderInfo; 2] = [
    ProviderInfo { id: "anthropic", label: "Anthropic (Claude)" },
    ProviderInfo { id: "openai", label: "OpenAI" },
];


const TIMEOUT: Duration = Duration::from_secs(20);

impl Provider {
    pub fn id(self) -> &'static str {
        match self {
            Provider::Anthropic => "anthropic",
            Provider::OpenAi => "openai",
        }
    }

    pub fn from_id(id: &str) -> Option<Self> {
        match id {
            "anthropic" => Some(Provider::Anthropic),
            "openai" => Some(Provider::OpenAi),
            _ => None,
        }
    }

    /// Asks the provider for a short title of the (already downscaled) JPEG.
    pub fn title_for(self, api_key: &str, jpeg: &[u8], instructions: Option<&str>) -> Result<String, Failure> {
        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        let prompt = prompt::build(instructions, &today);
        let data = base64::engine::general_purpose::STANDARD.encode(jpeg);
        let agent: ureq::Agent = ureq::Agent::config_builder()
            .timeout_global(Some(TIMEOUT))
            .http_status_as_error(false)
            .build()
            .into();
        let raw = match self {
            Provider::Anthropic => anthropic::request(&agent, api_key, &data, &prompt)?,
            Provider::OpenAi => openai::request(&agent, api_key, &data, &prompt)?,
        };
        Ok(clean_title(&raw))
    }
}



/// The provider's own `error.message` (both APIs use this shape), shortened.
/// It describes the request, never contains the key.
pub(super) fn error_detail(response: &mut ureq::http::Response<ureq::Body>) -> Option<String> {
    let json: serde_json::Value = response.body_mut().read_json().ok()?;
    let message = json.pointer("/error/message")?.as_str()?;
    Some(message.chars().take(200).collect())
}
