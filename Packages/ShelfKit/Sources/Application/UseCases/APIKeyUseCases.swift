import Foundation
import Domain

public protocol SaveAPIKeyUseCaseProtocol: Sendable {
    func execute(_ key: APIKey) throws
}

public struct SaveAPIKeyUseCase: SaveAPIKeyUseCaseProtocol {
    private let repository: APIKeyRepository
    public init(repository: APIKeyRepository) { self.repository = repository }
    public func execute(_ key: APIKey) throws { try repository.save(key) }
}

public protocol DeleteAPIKeyUseCaseProtocol: Sendable {
    func execute() throws
}

public struct DeleteAPIKeyUseCase: DeleteAPIKeyUseCaseProtocol {
    private let repository: APIKeyRepository
    public init(repository: APIKeyRepository) { self.repository = repository }
    public func execute() throws { try repository.delete() }
}

public protocol LoadAPIKeyStatusUseCaseProtocol: Sendable {
    func execute() throws -> APIKey?
}

public struct LoadAPIKeyStatusUseCase: LoadAPIKeyStatusUseCaseProtocol {
    private let repository: APIKeyRepository
    public init(repository: APIKeyRepository) { self.repository = repository }
    public func execute() throws -> APIKey? { try repository.load() }
}
