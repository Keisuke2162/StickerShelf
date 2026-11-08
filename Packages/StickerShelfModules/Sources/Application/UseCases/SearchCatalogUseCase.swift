import Foundation
import Domain

public protocol SearchCatalogUseCaseProtocol: Sendable {
    func execute(keyword: String, page: Int) async throws -> SearchCatalogOutput
}

public struct SearchCatalogOutput: Sendable {
    public struct Item: Sendable {
        public let catalog: CatalogBook
        public let alreadyRegistered: Bool
        public init(catalog: CatalogBook, alreadyRegistered: Bool) {
            self.catalog = catalog
            self.alreadyRegistered = alreadyRegistered
        }
    }
    public let items: [Item]
    public let totalItems: Int
    public let page: Int

    public init(items: [Item], totalItems: Int, page: Int) {
        self.items = items
        self.totalItems = totalItems
        self.page = page
    }
}

public struct SearchCatalogUseCase: SearchCatalogUseCaseProtocol {
    private let catalog: BookCatalogRepository
    private let books: BookRepository

    public init(catalog: BookCatalogRepository, books: BookRepository) {
        self.catalog = catalog
        self.books = books
    }

    public func execute(keyword: String, page: Int) async throws -> SearchCatalogOutput {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SearchCatalogOutput(items: [], totalItems: 0, page: page)
        }

        // 入力が ISBN として妥当なら ISBN 検索に切り替える。
        if let isbn = ISBN(trimmed) {
            if let book = try await catalog.find(isbn: isbn) {
                let registered = (try await books.fetch(isbn: isbn)) != nil
                return SearchCatalogOutput(
                    items: [.init(catalog: book, alreadyRegistered: registered)],
                    totalItems: 1,
                    page: 0
                )
            }
            return SearchCatalogOutput(items: [], totalItems: 0, page: 0)
        }

        let result = try await catalog.search(keyword: trimmed, page: page)
        var items: [SearchCatalogOutput.Item] = []
        items.reserveCapacity(result.books.count)
        for book in result.books {
            let registered: Bool
            if let isbn = book.metadata.isbn {
                registered = (try await books.fetch(isbn: isbn)) != nil
            } else {
                registered = false
            }
            items.append(.init(catalog: book, alreadyRegistered: registered))
        }
        return SearchCatalogOutput(items: items, totalItems: result.totalItems, page: result.page)
    }
}
