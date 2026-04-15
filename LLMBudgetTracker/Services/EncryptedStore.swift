import CryptoKit
import Foundation
import Security

enum EncryptedStore {
    private static let keychainService = "com.ilja82.lite-budget"
    private static let keychainAccount = "encrypted-store-key"

    // MARK: - Public

    static func set(_ data: Data, forKey key: String) throws {
        guard let symmetricKey = encryptionKey() else {
            throw EncryptedStoreError.keyUnavailable
        }
        guard let sealed = try? AES.GCM.seal(data, using: symmetricKey).combined else {
            throw EncryptedStoreError.encryptionFailed
        }
        UserDefaults.standard.set(sealed, forKey: key)
    }

    static func data(forKey key: String) -> Data? {
        guard let stored = UserDefaults.standard.data(forKey: key) else { return nil }
        guard let symmetricKey = encryptionKey(),
              let box = try? AES.GCM.SealedBox(combined: stored),
              let plain = try? AES.GCM.open(box, using: symmetricKey) else {
            return nil
        }
        return plain
    }

    static func remove(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Key management

    private static func encryptionKey() -> SymmetricKey? {
        if let keyData = loadKey() { return SymmetricKey(data: keyData) }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        guard saveKey(keyData) else { return nil }
        return key
    }

    private static func loadKey() -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecUseDataProtectionKeychain: true,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }

    @discardableResult
    private static func saveKey(_ data: Data) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecUseDataProtectionKeychain: true,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
}

enum EncryptedStoreError: LocalizedError {
    case keyUnavailable
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .keyUnavailable:
            return "Secure local storage is unavailable on this Mac."
        case .encryptionFailed:
            return "Failed to encrypt local app data."
        }
    }
}
