import Foundation
import Security

enum AppKeychain {
    static let service = "com.ilja82.lite-budget"
}

enum KeychainService {
    private static let account = "litellm-api-key"

    private static var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: AppKeychain.service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true
        ]
    }

    static func save(_ secret: String) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        var query = baseQuery
        query[kSecValueData] = data
        query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load() throws -> String {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }
        return secret
    }

    static func delete() {
        let query = baseQuery
        SecItemDelete(query as CFDictionary)
    }

    static var isConfigured: Bool {
        (try? load()) != nil
    }
}

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case notFound

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode secret"
        case .saveFailed(let s): return "Keychain write failed (OSStatus \(s))"
        case .notFound: return "No API key found — please configure one in Settings"
        }
    }
}
