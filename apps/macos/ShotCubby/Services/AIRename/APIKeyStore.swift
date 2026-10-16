import Foundation
import Security

/// API keys live in the macOS Keychain, never in `UserDefaults`. Mirrors
/// `api_key_store.rs` (Credential Manager on Windows).
enum APIKeyStore {
    struct SaveError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static let service = "com.nelahian.ShotCubby.api-key"

    private static func query(_ provider: LLMProvider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
    }

    static func get(_ provider: LLMProvider) -> String? {
        var request = query(provider)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        return key
    }

    static func has(_ provider: LLMProvider) -> Bool { get(provider) != nil }

    static func set(_ key: String, for provider: LLMProvider) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SaveError(message: "The key is empty") }
        delete(provider)
        var item = query(provider)
        item[kSecValueData as String] = Data(trimmed.utf8)
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw SaveError(message: "Could not save the key")
        }
    }

    static func delete(_ provider: LLMProvider) {
        SecItemDelete(query(provider) as CFDictionary)
    }
}
