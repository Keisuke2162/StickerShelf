/// 書籍検索 API から返ってきた、まだアプリに登録されていない本。
/// 書籍検索 API（book-api）は ISBN-13 を本を見分けるキーにしているので、
/// 検索結果の本は必ず ISBN を持ち、それを ID として使う（ISBN のない本は検索結果にならない）。
public struct CatalogBook: Hashable, Sendable, Identifiable {
  public let isbn: ISBN
  public let metadata: BookMetadata
  
  // isbnは一意になるのでidに使用
  public var id: String { isbn.value }
  
  /// - Throws: `metadata.isbn` が nil のとき `DomainError.invalidISBN`
  public init(metadata: BookMetadata) throws {
    guard let isbn = metadata.isbn else { throw DomainError.invalidISBN }
    self.isbn = isbn
    self.metadata = metadata
  }
}

/// キーワード検索の結果（1ページ分）。
public struct CatalogSearchResult: Sendable {
  public let books: [CatalogBook]
  /// 次のページがあるか。書籍検索 API は総件数を返さないので、件数ではなく続きの有無で表す。
  public let hasMore: Bool
  public let page: Int
  
  public init(books: [CatalogBook], hasMore: Bool, page: Int) {
    self.books = books
    self.hasMore = hasMore
    self.page = page
  }
}
