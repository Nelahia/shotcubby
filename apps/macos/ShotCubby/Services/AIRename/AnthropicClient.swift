import Foundation

enum AnthropicClient {
    private static let url = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-5-5"

    static func request(apiKey: String, jpeg: Data, prompt: String) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body(jpeg: jpeg, prompt: prompt))
        return try await LLMTransport.run(request, provider: "Anthropic", parse: title(in:))
    }

    private static func body(jpeg: Data, prompt: String) -> [String: Any] {
        [
            "model": model,
            // Haiku 5.5 thinks by default, and thinking is paid out of max_tokens: on a
            // busy screenshot it used the whole budget and left no text block
            // (stop reason max_tokens), so some captures were never named.
            "thinking": ["type": "disabled"],
            "max_tokens": 1024,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": [
                        "type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString(),
                    ]],
                    ["type": "text", "text": prompt],
                ],
            ]],
        ]
    }

    /// First non-empty text block of a Messages API response. Other blocks
    /// (e.g. thinking) may come first, so the first block is not assumed to be text.
    private static func title(in response: [String: Any]) -> String? {
        (response["content"] as? [[String: Any]])?
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
