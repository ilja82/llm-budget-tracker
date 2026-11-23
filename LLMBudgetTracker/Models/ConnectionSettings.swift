import Foundation

struct ConnectionSettings {
    let proxyURL: String
    let newAPIKey: String
    let apiKeyConfigured: Bool

    var isFormFilled: Bool {
        !proxyURL.isEmpty && (!newAPIKey.isEmpty || apiKeyConfigured)
    }

    /// The Keychain notice matters only while a key is entered.
    var showsKeychainNotice: Bool {
        !apiKeyConfigured || !newAPIKey.isEmpty
    }

    /// The connection fields start collapsed once a proxy URL and an API key are saved.
    static func startsCollapsed(savedURL: String, apiKeyConfigured: Bool) -> Bool {
        !savedURL.isEmpty && apiKeyConfigured
    }

    var canSave: Bool {
        isFormFilled && (try? EndpointSecurity.normalizedBaseURLString(from: proxyURL)) != nil
    }

    func apiKeyForTesting(load: () throws -> String) throws -> String {
        if !newAPIKey.isEmpty {
            return newAPIKey
        }
        return try load()
    }

    func saveAPIKeyIfNeeded(save: (String) throws -> Void) throws {
        if !newAPIKey.isEmpty {
            try save(newAPIKey)
        }
    }
}
