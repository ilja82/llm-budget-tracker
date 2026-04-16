import Foundation
import Security

enum AppKeychain {
    static let service = "com.ilja82.llm-budget-tracker"
}

enum KeychainService {
    private static let account = "litellm-api-key"

    private static var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: AppKeychain.service,
            kSecAttrAccount: account
        ]
    }

    static func save(_ secret: String) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.saveFailed(updateStatus)
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
