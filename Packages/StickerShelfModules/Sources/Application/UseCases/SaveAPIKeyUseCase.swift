import Foundation
import Domain

public protocol SaveAPIKeyUseCaseProtocol: Sendable {
    func execute(_ key: APIKey) throws
}

public struct SaveAPIKeyUseCase: SaveAPIKeyUseCaseProtocol {
    private let repository: APIKeyRepository

    public init(repository: APIKeyRepository) {
        self.repository = repository
    }

    public func execute(_ key: APIKey) throws {
        try repository.save(key)
    }
}
