use crate::services::i18n::tr;
use serde::Serialize;
use std::fmt;

/// Why a provider call failed. `kind` lets Settings explain the cause and the
/// fix in plain words; `message` is the short technical line. Neither ever
/// contains the key.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Kind {
    /// The Anthropic key is not tied to a workspace.
    Workspace,
    Rejected,
    Credit,
    RateLimit,
    Network,
    Other,
}

#[derive(Debug, Clone, Serialize)]
pub struct Failure {
    pub kind: Kind,
    pub message: String,
}

impl Failure {
    pub fn new(kind: Kind, message: impl Into<String>) -> Self {
        Failure { kind, message: message.into() }
    }

    pub fn other(message: impl Into<String>) -> Self {
        Failure::new(Kind::Other, message)
    }

    pub fn network(provider: &str) -> Self {
        Failure::new(Kind::Network, format!("{} {provider}", tr("Could not reach")))
    }

    /// Sorts a non-200 answer by what the provider said, since the same HTTP
    /// status (400) covers a missing workspace and an empty balance alike.
    pub fn from_status(status: u16, detail: Option<String>) -> Self {
        let lowered = detail.as_deref().unwrap_or_default().to_lowercase();
        if lowered.contains("workspace") {
            return Failure::new(Kind::Workspace, tr("This API key is not scoped to a workspace"));
        }
        if lowered.contains("credit balance") || lowered.contains("billing") || lowered.contains("quota") {
            return Failure::new(Kind::Credit, tr("The account has no credit left"));
        }
        match status {
            401 | 403 => Failure::new(Kind::Rejected, tr("The API key was rejected")),
            429 => Failure::new(Kind::RateLimit, tr("Too many requests, try again in a moment")),
            _ => Failure::other(match detail {
                Some(detail) => format!("{} {status}: {detail}", tr("The provider answered with HTTP")),
                None => format!("{} {status}", tr("The provider answered with HTTP")),
            }),
        }
    }
}

impl fmt::Display for Failure {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_missing_workspace_is_told_apart_from_other_400s() {
        let detail = "This API key is not scoped to a workspace, so this request must include the anthropic-workspace-id header";
        assert_eq!(Failure::from_status(400, Some(detail.into())).kind, Kind::Workspace);
        assert_eq!(Failure::from_status(400, Some("bad image".into())).kind, Kind::Other);
    }

    #[test]
    fn rejected_keys_and_empty_balances_are_recognised() {
        assert_eq!(Failure::from_status(401, None).kind, Kind::Rejected);
        let low = "Your credit balance is too low to access the API";
        assert_eq!(Failure::from_status(400, Some(low.into())).kind, Kind::Credit);
        assert_eq!(Failure::from_status(429, None).kind, Kind::RateLimit);
    }
}
