import Foundation

/// Sends a prepared request and hands the decoded JSON to `parse`. Errors
/// never carry the key.
enum LLMTransport {
    static func run(
        _ request: URLRequest, provider: String, parse: ([String: Any]) -> String?
    ) async throws -> String {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIFailure.network(provider)
        }
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw AIFailure.other("Unreadable answer from \(provider)")
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard status == 200 else {
            throw AIFailure.fromStatus(status, detail: errorDetail(in: json))
        }
        guard let json, let text = parse(json) else {
            throw AIFailure.other("No title in \(provider)'s answer")
        }
        return text
    }

    /// The provider's own `error.message` (both APIs use this shape), shortened.
    private static func errorDetail(in json: [String: Any]?) -> String? {
        let message = (json?["error"] as? [String: Any])?["message"] as? String
        return message.map { String($0.prefix(200)) }
    }
}
