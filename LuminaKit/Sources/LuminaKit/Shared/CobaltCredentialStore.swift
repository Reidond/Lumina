import Foundation
import Security

/// Keychain-backed store for per-host Cobalt API keys. Values are stored as generic
/// passwords keyed by instance host, optionally in a shared keychain access group so
/// the Share Extension can read them too.
public struct CobaltCredentialStore: Sendable {
    private let service: String
    private let accessGroup: String?

    public init(service: String = AppGroup.apiKeyKeychainService, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func apiKey(forHost host: String) -> String? {
        var query = baseQuery(account: host)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public func setAPIKey(_ key: String?, forHost host: String) -> Bool {
        // Remove first so we always end in a clean, single state.
        SecItemDelete(baseQuery(account: host) as CFDictionary)
        guard let key, !key.isEmpty, let data = key.data(using: .utf8) else { return true }
        var attributes = baseQuery(account: host)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    public func removeAPIKey(forHost host: String) {
        SecItemDelete(baseQuery(account: host) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}

public extension URL {
    /// Normalized host used as the keychain account / per-instance key.
    var instanceHostKey: String {
        (host()?.lowercased()).map { h in
            if let port = port { return "\(h):\(port)" }
            return h
        } ?? absoluteString.lowercased()
    }
}
