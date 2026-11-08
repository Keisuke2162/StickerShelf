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
  
  /// 次のページがあるか（ISBN 検索・空の入力では常に false）
  public let hasMore: Bool
  public let page: Int
  
  public init(items: [Item], hasMore: Bool, page: Int) {
    self.items = items
    self.hasMore = hasMore
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
      return SearchCatalogOutput(items: [], hasMore: false, page: page)
    }
    
    // 入力が ISBN として妥当なら ISBN 検索に切り替える。
    if let isbn = ISBN(trimmed) {
      if let book = try await catalog.find(isbn: isbn) {
        let registered = (try await books.fetch(isbn: isbn)) != nil
        return SearchCatalogOutput(
          items: [.init(catalog: book, alreadyRegistered: registered)],
          hasMore: false,
          page: 0
        )
      }
      return SearchCatalogOutput(items: [], hasMore: false, page: 0)
    }
    
    let result = try await catalog.search(keyword: trimmed, page: page)
    var items: [SearchCatalogOutput.Item] = []
    items.reserveCapacity(result.books.count)
    for book in result.books {
      // 検索結果の本は必ず ISBN を持つ（CatalogBook の不変条件）
      let registered = (try await books.fetch(isbn: book.isbn)) != nil
      items.append(.init(catalog: book, alreadyRegistered: registered))
    }
    return SearchCatalogOutput(items: items, hasMore: result.hasMore, page: result.page)
  }
}
