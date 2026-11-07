import Foundation
import Domain

public enum APIKeyStatus: Sendable, Equatable {
    case notSet
    case set(masked: String)
}

public protocol LoadAPIKeyStatusUseCaseProtocol: Sendable {
    func execute() throws -> APIKeyStatus
}

public struct LoadAPIKeyStatusUseCase: LoadAPIKeyStatusUseCaseProtocol {
    private let repository: APIKeyRepository

    public init(repository: APIKeyRepository) {
        self.repository = repository
    }

    /// 生キーを ViewModel に渡さない。設定画面にはマスク済み文字列と「設定済み」フラグだけが届く。
    public func execute() throws -> APIKeyStatus {
        guard let key = try repository.load() else { return .notSet }
        return .set(masked: key.description)
    }
}
