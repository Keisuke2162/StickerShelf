//
//  BookAPICatalogRepositoryTests.swift
//  InfrastructureTests
//
//  Created by Kei on 2026/11/08.
//

import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

/// APIの呼び出し、変換のテスト
/// StubURLProtocolで通信を差し替えてネットワークなしで単体テスト
/// → URLSessionを差し替えてリクエストの組手たて、DTOからDomain型への変換などをテスト
///  .serializedはこのグループ(Suite)のテストを1つずつ順番に動かすこと。→StubURLProtocolがどんなレスポンスを返すかを全テストで共有するから
@Suite("BookAPICatalogRepository", .serialized)
struct BookAPICatalogRepositoryTests {
  private let baseURL = URL(string: "https://book-api.example.workers.dev").unsafelyUnwrapped
  
  private func makeRepository(session: URLSession) -> BookAPICatalogRepository {
    BookAPICatalogRepository(client: BookAPIClient(session: session, baseURL: baseURL))
  }
  
  
  @Test func search_callSearchEndpoint_withOneBasePage() async throws {
    // テスト内容：キーワード検索で、API に送るリクエストが正しく組み立てられるか
    let data = try FixtureLoader.data("bookapi_search")
    let session = URLSession.stubbed { _ in .init(statusCode: 200, data: data) }
    let repo = makeRepository(session: session)
    _ = try await repo.search(keyword: "夏目漱石", page: 0)
    // Stub側で保持してるリクエストの記録を取り出し（正しいリクエストかどうかのテストを行うため）
    let seen = StubURLProtocol.recordedRequests()
    
    // 確認：リクエストが1回だけ送られ、パス・q・page（アプリの0 → APIの1）・User-Agent が想定どおりであること
    #expect(seen.count == 1)
    // resolvingAgainstBaseURL：相対URLなら基準URLと組み合わせてから分解するか（今回は絶対URLなので影響なし）
    let url = try #require(seen[0].url)
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let queryItems = components?.queryItems ?? []
    #expect(components?.path == "/v1/books/search")
    #expect(queryItems.contains(where: { $0.name == "q" && $0.value == "夏目漱石" }))
    #expect(queryItems.contains(where: { $0.name == "page" && $0.value == "1" }))
    #expect(seen[0].value(forHTTPHeaderField: "User-Agent") == "StickerShelf/1.0 iOS")
  }
  
  @Test func search_mapsBooksToCatalogBooks() async throws {
    // テスト内容：検索結果の JSON が、CatalogBook と CatalogSearchResult に正しく変換されるか
    let data = try FixtureLoader.data("bookapi_search")
    let session = URLSession.stubbed { _ in .init(statusCode: 200, data: data) }
    let repo = makeRepository(session: session)
    let result = try await repo.search(keyword: "こころ", page: 0)
    // 確認：page・hasMore・件数が想定どおりであること
    #expect(result.page == 0)
    #expect(result.hasMore == true)
    #expect(result.books.count == 2)
    
    // 確認：1冊目の各項目が、JSON の値どおりに入っていること
    let first = result.books[0].metadata
    #expect(first.title == "こゝろ")
    #expect(first.authors == ["夏目漱石"])
    #expect(first.publisher == "岩波書店")
    #expect(first.publishedDate == "1989-05")
    #expect(first.pageCount == 337)
    #expect(first.isbn?.value == "9784003101018")
    #expect(result.books[0].id == "9784003101018")
    #expect(first.remoteCoverURL?.absoluteString == "https://example.com/covers/9784003101018.jpg")
    
    // 確認：書影・ページ数がない本は、その項目が nil になること
    let second = result.books[1].metadata
    #expect(second.remoteCoverURL == nil)
    #expect(second.pageCount == nil)
  }
  
  @Test func search_doesNotCallAPI_beyondMaxPage() async throws {
    // テスト内容：API の上限（page 25）を超えるページを求めたとき、API を呼ばずに空の結果を返すか
    let session = URLSession.stubbed { _ in .init(statusCode: 200, data: Data()) }
    let repo = makeRepository(session: session)
    // アプリの page 25 は API の page 26 で、上限（25）を超える
    let result = try await repo.search(keyword: "x", page: 25)
    // 確認：結果が空で hasMore が false、リクエストが送られていないこと
    #expect(result.books.isEmpty)
    #expect(result.hasMore == false)
    #expect(StubURLProtocol.recordedRequests().isEmpty)
  }
  
  @Test func find_callsIsbnEndpoint_andMapsBook() async throws {
    // テスト内容：ISBN検索で、ISBN のパスにリクエストを送り、結果を CatalogBook に変換するか
    let data = try FixtureLoader.data("bookapi_isbn")
    let session = URLSession.stubbed { _ in .init(statusCode: 200, data: data) }
    let repo = makeRepository(session: session)
    let book = try await repo.find(isbn: ISBN("9784832203655")!)
    // 確認：リクエストのパスと、変換後の ISBN・ページ数が想定どおりであること
    #expect(StubURLProtocol.recordedRequests().first?.url?.path == "/v1/books/isbn/9784832203655")
    #expect(book?.metadata.isbn?.value == "9784832203655")
    #expect(book?.metadata.pageCount == 174)
  }
  
  @Test func find_returnsNil_on404() async throws {
    // テスト内容：ISBN検索で本が見つからない（404）とき、エラーではなく nil を返すか
    let body = Data(#"{"error":"not_found","message":"該当する本が見つかりませんでした"}"#.utf8)
    let session = URLSession.stubbed { _ in .init(statusCode: 404, data: body) }
    let repo = makeRepository(session: session)
    let book = try await repo.find(isbn: ISBN("9784832203655")!)
    // 確認：結果が nil であること
    #expect(book == nil)
  }
  
  @Test func maps429_toQuotaExceeded() async throws {
    // テスト内容：API の回数制限（429）が、DomainError.catalogQuotaExceeded になるか
    let session = URLSession.stubbed { _ in .init(statusCode: 429, data: Data(), headers: ["Retry-After": "60"]) }
    let repo = makeRepository(session: session)
    // 確認：catalogQuotaExceeded が投げられること
    await #expect(throws: DomainError.catalogQuotaExceeded) {
      _ = try await repo.search(keyword: "x", page: 0)
    }
  }
  
  @Test func maps502_toCatalogUnavailable() async throws {
    // テスト内容：API の書籍データ取得失敗（502）が、DomainError.catalogUnavailable になるか
    let body = Data(#"{"error":"upstream_unavailable","message":"down"}"#.utf8)
    let session = URLSession.stubbed { _ in .init(statusCode: 502, data: body) }
    let repo = makeRepository(session: session)
    // 確認：エラーの理由に、ステータスと API のメッセージが入っていること
    await #expect(throws: DomainError.catalogUnavailable(reason: "server error 502: down")) {
      _ = try await repo.search(keyword: "x", page: 0)
    }
  }
  
  @Test func mapsOffline_toNetwork() async throws {
    // テスト内容：オフラインなどの通信エラーが、DomainError.network になるか
    let session = URLSession.stubbed { _ in throw URLError(.notConnectedToInternet) }
    let repo = makeRepository(session: session)
    // 確認：network が投げられること
    await #expect(throws: DomainError.network) {
      _ = try await repo.search(keyword: "x", page: 0)
    }
  }
}

