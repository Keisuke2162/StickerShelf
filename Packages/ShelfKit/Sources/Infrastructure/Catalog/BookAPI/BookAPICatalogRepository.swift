//
//  BookAPICatalogRepository.swift
//  ShelfKit
//
//  Created by Kei on 2026/11/08.
//

import Foundation
import Domain

/// BookCatalogRepositoryの具体実装。自前のAPIをコール
public struct BookAPICatalogRepository: BookCatalogRepository {
  /// pageの上限（API側の仕様として1-25）
  static let maxPage = 25
  /// 検索語の長さの上限
  static let maxQueryLength = 100
  
  private let client: BookAPIClient
  
  public init(client: BookAPIClient) {
    self.client = client
  }

  /// キーワード検索
  /// 検索ワードがISBNかキーワードどうかの判定はUseCase側で行い、キーワードの場合のみこのメソッドがコールされる
  public func search(keyword: String, page: Int) async throws -> CatalogSearchResult {
    // アプリ側は0開始、API側は1開始なのでAPI用に+1する
    let apiPage = page + 1
    guard apiPage <= Self.maxPage else {
      // 【暫定】Domain がまだ totalItems を持つため。5-11 で hasMore に置き換える
      return CatalogSearchResult(books: [], totalItems: 0, page: page)
    }
    // 長すぎる検索語は400になるので先に詰めておく
    let query = String(keyword.prefix(Self.maxQueryLength))
    let dto = try await client.search(query: query, page: apiPage)
    // アプリ用のpageに戻る
    return BookAPIMapper.toCatalogSearchResult(dto, page: page)
  }
  
  /// ISBN で本を1冊取得する。見つからなければ nil を返す。
  public func find(isbn: Domain.ISBN) async throws -> CatalogBook? {
    guard let dto = try await client.book(isbn: isbn) else { return nil }
    return BookAPIMapper.toCatalogBook(dto)
  }
}
