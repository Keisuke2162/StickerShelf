/// 書籍検索 API から返ってきた、まだアプリに登録されていない本。
public struct CatalogBook: Hashable, Sendable {
    public let metadata: BookMetadata

    public init(metadata: BookMetadata) {
        self.metadata = metadata
    }
}

public struct CatalogSearchResult: Sendable {
    public let books: [CatalogBook]
    public let totalItems: Int
    public let page: Int

    public init(books: [CatalogBook], totalItems: Int, page: Int) {
        self.books = books
        self.totalItems = totalItems
        self.page = page
    }
}
