import Foundation
import Domain

public enum CatalogConnectionTestResult: Sendable, Equatable {
    case success
    case invalidAPIKey
    case quotaExceeded
    case networkUnavailable
    case serviceUnavailable
    case unknown
}

public protocol TestCatalogConnectionUseCaseProtocol: Sendable {
    func execute() async -> CatalogConnectionTestResult
}

public struct TestCatalogConnectionUseCase: TestCatalogConnectionUseCaseProtocol {
    /// Notion 04 で接続テスト用に推奨されている ISBN。
    public static let defaultProbeISBN: ISBN = {
        guard let isbn = ISBN("9784101010014") else {
            fatalError("default probe ISBN is invalid — fix the source constant")
        }
        return isbn
    }()

    private let catalog: BookCatalogRepository
    private let probeISBN: ISBN

    public init(catalog: BookCatalogRepository, probeISBN: ISBN = TestCatalogConnectionUseCase.defaultProbeISBN) {
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
            case .catalogUnavailable: return .serviceUnavailable
            default: return .unknown
            }
        } catch {
            return .unknown
        }
    }
}
