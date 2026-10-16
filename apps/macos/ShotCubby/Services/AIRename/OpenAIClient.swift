import Foundation

enum OpenAIClient {
    private static let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let model = "gpt-4o-mini"

    static func request(apiKey: String, jpeg: Data, prompt: String) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body(jpeg: jpeg, prompt: prompt))
        return try await LLMTransport.run(request, provider: "OpenAI", parse: title(in:))
    }

    private static func body(jpeg: Data, prompt: String) -> [String: Any] {
        [
            "model": model,
            "max_tokens": 40,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": [
                        "url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
                    ]],
                ],
            ]],
        ]
    }

    /// Message of the first choice of a Chat Completions response.
    private static func title(in response: [String: Any]) -> String? {
        let message = (response["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
        return message?["content"] as? String
    }
}
