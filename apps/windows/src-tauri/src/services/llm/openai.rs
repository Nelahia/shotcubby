use super::Failure;
use serde_json::{Value, json};

const URL: &str = "https://api.openai.com/v1/chat/completions";
const MODEL: &str = "gpt-4o-mini";

fn body(image_base64: &str, prompt: &str) -> Value {
    json!({
        "model": MODEL,
        "max_tokens": 40,
        "messages": [{
            "role": "user",
            "content": [
                { "type": "text", "text": prompt },
                { "type": "image_url", "image_url": { "url": format!("data:image/jpeg;base64,{image_base64}") } }
            ]
        }]
    })
}

/// Message of the first choice of a Chat Completions response.
fn parse(response: &Value) -> Option<String> {
    response.pointer("/choices/0/message/content")?.as_str().map(str::to_owned)
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
    parse(&json).ok_or_else(|| Failure::other("No title in OpenAI's answer"))
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
    fn rejects_an_answer_without_choices() {
        assert_eq!(parse(&json!({ "choices": [] })), None);
    }
}
