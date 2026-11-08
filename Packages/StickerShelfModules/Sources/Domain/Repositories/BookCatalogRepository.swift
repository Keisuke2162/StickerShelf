public protocol BookCatalogRepository: Sendable {
    func search(keyword: String, page: Int) async throws -> CatalogSearchResult
    func find(isbn: ISBN) async throws -> CatalogBook?
}
