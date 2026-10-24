use super::Failure;
use serde_json::{Value, json};

const URL: &str = "https://api.anthropic.com/v1/messages";
const MODEL: &str = "claude-haiku-5-5";

fn body(image_base64: &str, prompt: &str) -> Value {
    json!({
        "model": MODEL,
        // Haiku 5.5 thinks by default, and thinking is paid out of max_tokens: on a
        // busy screenshot it used the whole budget and left no text block
        // (stop reason max_tokens), so some captures were never named. A title
        // needs no reasoning.
        "thinking": { "type": "disabled" },
        "max_tokens": 1024,
        "messages": [{
            "role": "user",
            "content": [
                { "type": "image", "source": { "type": "base64", "media_type": "image/jpeg", "data": image_base64 } },
                { "type": "text", "text": prompt }
            ]
        }]
    })
}

/// First non-empty text block of a Messages API response. Other blocks
/// (e.g. thinking) may come first, so the first block is not assumed to be text.
fn parse(response: &Value) -> Option<String> {
    response
        .get("content")?
        .as_array()?
        .iter()
        .filter(|block| block.get("type").and_then(Value::as_str) == Some("text"))
        .filter_map(|block| block.get("text").and_then(Value::as_str))
        .find(|text| !text.trim().is_empty())
        .map(str::to_owned)
}

/// Why an answer had no title, for the Settings "Last result" line.
fn describe_empty(response: &Value) -> String {
    let reason = response.get("stop_reason").and_then(Value::as_str).unwrap_or("unknown");
    format!("No title in Anthropic's answer (stop reason: {reason})")
}

pub fn request(agent: &ureq::Agent, api_key: &str, image_base64: &str, prompt: &str) -> Result<String, Failure> {
    let mut response = agent
        .post(URL)
        .header("x-api-key", api_key)
        .header("anthropic-version", "2023-06-01")
        .send_json(body(image_base64, prompt))
        .map_err(|_| Failure::network("Anthropic"))?;
    let status = response.status().as_u16();
    if status != 200 {
        return Err(Failure::from_status(status, super::error_detail(&mut response)));
    }
    let json: Value = response
        .body_mut()
        .read_json()
        .map_err(|_| Failure::other("Unreadable answer from Anthropic"))?;
    parse(&json).ok_or_else(|| Failure::other(describe_empty(&json)))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_the_first_text_block() {
        let response = json!({ "content": [{ "type": "text", "text": "Invoice March" }] });
        assert_eq!(parse(&response).as_deref(), Some("Invoice March"));
    }

    #[test]
    fn the_request_turns_thinking_off_so_it_cannot_eat_the_token_budget() {
        let request = body("AAAA", "Name it");
        assert_eq!(request["thinking"]["type"], "disabled");
        assert_eq!(request["max_tokens"], 1024);
    }

    #[test]
    fn skips_blocks_that_are_not_text() {
        let response = json!({ "content": [
            { "type": "thinking", "thinking": "hmm" },
            { "type": "text", "text": "Pricing table" }
        ] });
        assert_eq!(parse(&response).as_deref(), Some("Pricing table"));
    }

    #[test]
    fn rejects_an_answer_without_text() {
        assert_eq!(parse(&json!({ "content": [] })), None);
    }
}
