import Security
import Foundation

/// Simple Keychain wrapper for storing secrets (API keys, tokens, etc.)
final class KeychainService {

    private let service = "com.flowbar.secrets"

    // MARK: - Public

    func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(forKey: key)

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func get(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    func allKeys() -> [String] {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecReturnAttributes: true,
            kSecMatchLimit:       kSecMatchLimitAll
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[CFString: Any]] else { return [] }
        return items.compactMap { $0[kSecAttrAccount] as? String }
    }
}
