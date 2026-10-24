import Foundation

struct ConnectionSettings {
    let proxyURL: String
    let newAPIKey: String
    let apiKeyConfigured: Bool

    var isFormFilled: Bool {
        !proxyURL.isEmpty && (!newAPIKey.isEmpty || apiKeyConfigured)
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
