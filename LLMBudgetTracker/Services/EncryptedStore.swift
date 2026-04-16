import CryptoKit
import Foundation
import Security

enum EncryptedStore {
    private static let keychainAccount = "encrypted-store-key"

    // MARK: - Public

    static func set(_ data: Data, forKey key: String) throws {
        let symmetricKey = try encryptionKey()
        guard let sealed = try? AES.GCM.seal(data, using: symmetricKey).combined else {
            throw EncryptedStoreError.encryptionFailed
        }
        UserDefaults.standard.set(sealed, forKey: key)
    }

    static func data(forKey key: String) throws -> Data? {
        guard let stored = UserDefaults.standard.data(forKey: key) else { return nil }
        guard let symmetricKey = try existingEncryptionKey() else {
            throw EncryptedStoreError.keyUnavailable
        }
        guard let box = try? AES.GCM.SealedBox(combined: stored),
              let plain = try? AES.GCM.open(box, using: symmetricKey) else {
            throw EncryptedStoreError.decryptionFailed
        }
        return plain
    }

    static func remove(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Key management

    private static func encryptionKey() throws -> SymmetricKey {
        if let key = try existingEncryptionKey() {
            return key
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        guard saveKey(keyData) else { throw EncryptedStoreError.keyUnavailable }
        return key
    }

    private static func existingEncryptionKey() throws -> SymmetricKey? {
        guard let keyData = try loadKey() else { return nil }
        return SymmetricKey(data: keyData)
    }

    private static func loadKey() throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: AppKeychain.service,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw EncryptedStoreError.keyUnavailable
        }
        return data
    }

    @discardableResult
    private static func saveKey(_ data: Data) -> Bool {
        let lookupQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: AppKeychain.service,
            kSecAttrAccount: keychainAccount
        ]
        SecItemDelete(lookupQuery as CFDictionary)
        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: AppKeychain.service,
            kSecAttrAccount: keychainAccount,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
}

enum EncryptedStoreError: LocalizedError {
    case keyUnavailable
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .keyUnavailable:
            return "Secure local storage is unavailable on this Mac."
        case .encryptionFailed:
            return "Failed to encrypt local app data."
        case .decryptionFailed:
            return "Failed to read local encrypted app data."
        }
    }
}
