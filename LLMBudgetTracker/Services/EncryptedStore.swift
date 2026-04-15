import CryptoKit
import Foundation
import Security

/// Thin wrapper that transparently encrypts/decrypts `Data` values in `UserDefaults`
/// using AES-GCM with a per-device `SymmetricKey` stored in the Keychain.
///
/// Graceful degradation: if the Keychain is unavailable, values are stored/read as
/// plaintext. If decryption fails (e.g. legacy unencrypted data), the raw bytes are
/// returned so callers can attempt their own JSON decode — enabling silent migration.
enum EncryptedStore {
    private static let keychainService = "com.ilja82.lite-budget"
    private static let keychainAccount = "encrypted-store-key"

    // MARK: - Public

    static func set(_ data: Data, forKey key: String) {
        guard let symmetricKey = encryptionKey(),
              let sealed = try? AES.GCM.seal(data, using: symmetricKey).combined else {
            #if DEBUG
            print("[EncryptedStore] WARNING: Keychain unavailable — storing '\(key)' as plaintext")
            #endif
            assertionFailure("EncryptedStore: Keychain unavailable, data stored unencrypted for key '\(key)'")
            UserDefaults.standard.set(data, forKey: key)
            return
        }
        UserDefaults.standard.set(sealed, forKey: key)
    }

    static func data(forKey key: String) -> Data? {
        guard let stored = UserDefaults.standard.data(forKey: key) else { return nil }
        guard let symmetricKey = encryptionKey() else { return stored }
        if let box = try? AES.GCM.SealedBox(combined: stored),
           let plain = try? AES.GCM.open(box, using: symmetricKey) {
            return plain
        }
        // Decryption failed — data may be legacy plaintext; let the caller decide
        return stored
    }

    static func remove(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Key management

    private static func encryptionKey() -> SymmetricKey? {
        if let keyData = loadKey() { return SymmetricKey(data: keyData) }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        saveKey(keyData)
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

    private static func saveKey(_ data: Data) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecUseDataProtectionKeychain: true,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
