import Foundation
import Domain

public protocol FindCatalogBookByISBNUseCaseProtocol: Sendable {
    func execute(isbn: ISBN) async throws -> CatalogBook?
}

public struct FindCatalogBookByISBNUseCase: FindCatalogBookByISBNUseCaseProtocol {
    private let catalog: BookCatalogRepository

    public init(catalog: BookCatalogRepository) {
        self.catalog = catalog
    }

    public func execute(isbn: ISBN) async throws -> CatalogBook? {
        try await catalog.find(isbn: isbn)
    }
}
