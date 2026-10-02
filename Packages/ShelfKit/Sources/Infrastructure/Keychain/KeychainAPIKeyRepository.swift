import Foundation
import Security
import Domain

public struct KeychainAPIKeyRepository: APIKeyRepository {
    public let service: String
    public let account: String
    public let fallback: (@Sendable () -> APIKey?)?

    public init(service: String, account: String = "googleBooksAPIKey", fallback: (@Sendable () -> APIKey?)? = nil) {
        self.service = service
        self.account = account
        self.fallback = fallback
    }

    public func load() throws -> APIKey? {
        var query: [String: Any] = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let raw = String(data: data, encoding: .utf8),
                  let key = APIKey(raw)
            else { return fallback?() }
            return key
        case errSecItemNotFound:
            return fallback?()
        default:
            throw NSError(domain: "KeychainAPIKeyRepository", code: Int(status))
        }
    }

    public func save(_ key: APIKey) throws {
        let data = Data(key.rawValue.utf8)
        var query = baseQuery()
        let update: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(query as CFDictionary, nil)
        }
        if status != errSecSuccess {
            throw NSError(domain: "KeychainAPIKeyRepository", code: Int(status))
        }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw NSError(domain: "KeychainAPIKeyRepository", code: Int(status))
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
