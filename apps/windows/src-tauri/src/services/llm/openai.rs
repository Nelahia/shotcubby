use super::Failure;
use serde_json::{Value, json};

const URL: &str = "https://api.openai.com/v1/chat/completions";
const MODEL: &str = "gpt-5-nano";

fn body(image_base64: &str, prompt: &str) -> Value {
    json!({
        "model": MODEL,
        // GPT-5 models reason before answering: `max_tokens` is refused, the
        // limit is `max_completion_tokens` and it also covers the reasoning,
        // which is kept to a minimum. The ceiling leaves room for it: at 300 a
        // busy screenshot could spend it all reasoning and return an empty title.
        "max_completion_tokens": 1024,
        "reasoning_effort": "minimal",
        "messages": [{
            "role": "user",
            "content": [
                { "type": "text", "text": prompt },
                { "type": "image_url", "image_url": { "url": format!("data:image/jpeg;base64,{image_base64}") } }
            ]
        }]
    })
}

/// Message of the first choice of a Chat Completions response, if it has text.
fn parse(response: &Value) -> Option<String> {
    response
        .pointer("/choices/0/message/content")?
        .as_str()
        .filter(|text| !text.trim().is_empty())
        .map(str::to_owned)
}

/// Why an answer had no title, for the Settings "Last result" line.
fn describe_empty(response: &Value) -> String {
    let reason = response.pointer("/choices/0/finish_reason").and_then(Value::as_str).unwrap_or("unknown");
    format!("No title in OpenAI's answer (finish reason: {reason})")
}

pub fn request(agent: &ureq::Agent, api_key: &str, image_base64: &str, prompt: &str) -> Result<String, Failure> {
    let mut response = agent
        .post(URL)
        .header("Authorization", &format!("Bearer {api_key}"))
        .send_json(body(image_base64, prompt))
        .map_err(|_| Failure::network("OpenAI"))?;
    let status = response.status().as_u16();
    if status != 200 {
        return Err(Failure::from_status(status, super::error_detail(&mut response)));
    }
    let json: Value = response
        .body_mut()
        .read_json()
        .map_err(|_| Failure::other("Unreadable answer from OpenAI"))?;
    parse(&json).ok_or_else(|| Failure::other(describe_empty(&json)))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_the_first_choice() {
        let response = json!({ "choices": [{ "message": { "content": "Pricing table" } }] });
        assert_eq!(parse(&response).as_deref(), Some("Pricing table"));
    }

    #[test]
    fn the_request_uses_the_gpt_5_parameters() {
        let request = body("AAAA", "Name it");
        assert_eq!(request["model"], "gpt-5-nano");
        assert_eq!(request["max_completion_tokens"], 1024);
        assert_eq!(request["reasoning_effort"], "minimal");
        assert!(request.get("max_tokens").is_none());
    }

    #[test]
    fn an_empty_message_is_not_a_title_and_the_reason_is_reported() {
        let response = json!({ "choices": [{ "message": { "content": "" }, "finish_reason": "length" }] });
        assert_eq!(parse(&response), None);
        assert_eq!(describe_empty(&response), "No title in OpenAI's answer (finish reason: length)");
    }

    #[test]
    fn rejects_an_answer_without_choices() {
        assert_eq!(parse(&json!({ "choices": [] })), None);
    }
}
