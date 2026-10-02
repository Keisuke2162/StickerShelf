import Foundation
import Domain

public final class InMemoryAPIKeyRepository: APIKeyRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var current: APIKey?

    public init(_ initial: APIKey? = nil) {
        self.current = initial
    }

    public func load() throws -> APIKey? {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    public func save(_ key: APIKey) throws {
        lock.lock(); defer { lock.unlock() }
        current = key
    }

    public func delete() throws {
        lock.lock(); defer { lock.unlock() }
        current = nil
    }
}
