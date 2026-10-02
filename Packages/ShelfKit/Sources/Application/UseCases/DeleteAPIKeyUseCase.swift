import Foundation
import Domain

public protocol DeleteAPIKeyUseCaseProtocol: Sendable {
    func execute() throws
}

public struct DeleteAPIKeyUseCase: DeleteAPIKeyUseCaseProtocol {
    private let repository: APIKeyRepository

    public init(repository: APIKeyRepository) {
        self.repository = repository
    }

    public func execute() throws {
        try repository.delete()
    }
}
