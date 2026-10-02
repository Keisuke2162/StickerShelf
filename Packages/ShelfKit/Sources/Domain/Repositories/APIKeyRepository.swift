public protocol APIKeyRepository: Sendable {
    func load() throws -> APIKey?
    func save(_ key: APIKey) throws
    func delete() throws
}
