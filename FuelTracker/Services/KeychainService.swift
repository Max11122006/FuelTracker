import Foundation
import Security

/// Stores and retrieves the Fuel Finder API credentials from the iOS Keychain.
/// Credentials never touch UserDefaults, disk files, or source control.
final class KeychainService {
    static let shared = KeychainService()
    private init() {}

    // MARK: - Public types

    struct Credentials {
        let clientID: String
        let clientSecret: String

        var isConfigured: Bool {
            !clientID.isEmpty && !clientSecret.isEmpty
        }
    }

    // MARK: - Save

    func save(clientID: String, clientSecret: String) {
        set(value: clientID,     for: Keys.clientID)
        set(value: clientSecret, for: Keys.clientSecret)
    }

    // MARK: - Load

    func loadCredentials() -> Credentials? {
        guard
            let id     = get(for: Keys.clientID),
            let secret = get(for: Keys.clientSecret),
            !id.isEmpty, !secret.isEmpty
        else { return nil }
        return Credentials(clientID: id, clientSecret: secret)
    }

    func loadClientID()     -> String { get(for: Keys.clientID)     ?? "" }
    func loadClientSecret() -> String { get(for: Keys.clientSecret) ?? "" }

    // MARK: - Delete

    func deleteCredentials() {
        delete(for: Keys.clientID)
        delete(for: Keys.clientSecret)
    }

    var hasCredentials: Bool {
        loadCredentials() != nil
    }

    // MARK: - Private helpers

    private func set(value: String, for key: String) {
        let data = value.data(using: .utf8)!

        // Delete any existing item first (update pattern)
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Keys.service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrService as String:          Keys.service,
            kSecAttrAccount as String:          key,
            kSecValueData as String:            data,
            kSecAttrAccessible as String:       kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func get(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Keys.service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    private func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Keys.service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    private enum Keys {
        static let service      = "com.maxd.FuelTracker.fuelFinder"
        static let clientID     = "clientID"
        static let clientSecret = "clientSecret"
    }
}
