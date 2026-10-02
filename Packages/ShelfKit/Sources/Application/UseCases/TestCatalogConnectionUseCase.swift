import Foundation
import Domain

public enum CatalogConnectionTestResult: Sendable, Equatable {
    case success
    case invalidAPIKey
    case quotaExceeded
    case networkUnavailable
    case other(String)
}

public protocol TestCatalogConnectionUseCaseProtocol: Sendable {
    func execute() async -> CatalogConnectionTestResult
}

public struct TestCatalogConnectionUseCase: TestCatalogConnectionUseCaseProtocol {
    private let catalog: BookCatalogRepository
    private let probeISBN: ISBN

    public init(catalog: BookCatalogRepository, probeISBN: ISBN = ISBN("9784101010014").unsafelyUnwrapped) {
        self.catalog = catalog
        self.probeISBN = probeISBN
    }

    public func execute() async -> CatalogConnectionTestResult {
        do {
            _ = try await catalog.find(isbn: probeISBN)
            return .success
        } catch let error as DomainError {
            switch error {
            case .invalidAPIKey: return .invalidAPIKey
            case .catalogQuotaExceeded: return .quotaExceeded
            case .network: return .networkUnavailable
            case .catalogUnavailable(let reason): return .other(reason)
            default: return .other(String(describing: error))
            }
        } catch {
            return .other(error.localizedDescription)
        }
    }
}
