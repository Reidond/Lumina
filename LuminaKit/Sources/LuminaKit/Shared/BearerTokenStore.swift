import Foundation
import Security

/// Keychain store for per-host Bearer tokens minted via Turnstile, with their expiry.
public struct BearerTokenStore: Sendable {
    private let service: String
    private let accessGroup: String?

    public init(service: String = AppGroup.bearerKeychainService, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    private struct Stored: Codable {
        let token: String
        let exp: Date
    }

    /// Returns the token only if it exists and won't expire within 30s.
    public func validToken(forHost host: String, now: Date = Date()) -> String? {
        guard let stored = read(host), stored.exp > now.addingTimeInterval(30) else { return nil }
        return stored.token
    }

    public func store(token: String, exp: Date, forHost host: String) {
        guard let data = try? JSONEncoder().encode(Stored(token: token, exp: exp)) else { return }
        SecItemDelete(baseQuery(account: host) as CFDictionary)
        var attributes = baseQuery(account: host)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    public func remove(forHost host: String) {
        SecItemDelete(baseQuery(account: host) as CFDictionary)
    }

    private func read(_ host: String) -> Stored? {
        var query = baseQuery(account: host)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }
}
