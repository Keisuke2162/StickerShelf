import Foundation
import Domain

public final class StubCatalogRepository: BookCatalogRepository, @unchecked Sendable {
    public var searchResult: Result<CatalogSearchResult, Error>?
    public var findResult: Result<CatalogBook?, Error>?

    public init() {}

    public func search(keyword: String, page: Int) async throws -> CatalogSearchResult {
        switch searchResult {
        case .success(let value): return value
        case .failure(let error): throw error
        case .none: return CatalogSearchResult(books: [], totalItems: 0, page: page)
        }
    }

    public func find(isbn: ISBN) async throws -> CatalogBook? {
        switch findResult {
        case .success(let value): return value
        case .failure(let error): throw error
        case .none: return nil
        }
    }
}
