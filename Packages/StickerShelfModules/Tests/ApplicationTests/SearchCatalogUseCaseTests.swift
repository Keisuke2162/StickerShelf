import Testing
import Foundation
@testable import Application
@testable import Domain

@Suite("SearchCatalogUseCase")
struct SearchCatalogUseCaseTests {
  @Test func switchesToISBNSearchWhenInputIsISBN() async throws {
    let books = InMemoryBookRepository()
    let catalog = StubCatalogRepository()
    let meta = try BookMetadata(title: "見つけた", isbn: ISBN("9784101010014"))
    catalog.findResult = .success(try CatalogBook(metadata: meta))
    let useCase = SearchCatalogUseCase(catalog: catalog, books: books)
    let out = try await useCase.execute(keyword: "978-4-10-101001-4", page: 0)
    #expect(out.items.count == 1)
    #expect(out.items[0].alreadyRegistered == false)
  }
  
  @Test func marksAlreadyRegisteredWhenISBNMatchesStoredBook() async throws {
    let isbn = ISBN("9784101010014")!
    let books = InMemoryBookRepository()
    let meta = try BookMetadata(title: "登録済み", isbn: isbn)
    try await books.save(try Book(metadata: meta, status: .unread, addedAt: Date()))
    
    let catalog = StubCatalogRepository()
    catalog.searchResult = .success(CatalogSearchResult(
      books: [try CatalogBook(metadata: meta)],
      hasMore: true,
      page: 0
    ))
    let useCase = SearchCatalogUseCase(catalog: catalog, books: books)
    let out = try await useCase.execute(keyword: "宇宙", page: 0)
    #expect(out.items.first?.alreadyRegistered == true)
    #expect(out.hasMore == true)
  }
  
  @Test func emptyKeywordReturnsEmpty() async throws {
    let books = InMemoryBookRepository()
    let catalog = StubCatalogRepository()
    let useCase = SearchCatalogUseCase(catalog: catalog, books: books)
    let out = try await useCase.execute(keyword: "   ", page: 0)
    #expect(out.items.isEmpty)
    #expect(out.hasMore == false)
  }

  @Test func catalogBookRequiresISBN() throws {
    // テスト内容：ISBN のない本から CatalogBook を作れないか（検索結果の本は ISBN-13 で見分けるため）
    let meta = try BookMetadata(title: "ISBN なし")
    // 確認：DomainError.invalidISBN が投げられること
    #expect(throws: DomainError.invalidISBN) {
      _ = try CatalogBook(metadata: meta)
    }
  }
}
