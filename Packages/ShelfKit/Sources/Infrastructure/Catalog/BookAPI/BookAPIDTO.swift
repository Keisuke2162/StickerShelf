//
//  BookAPIDTO.swift
//  ShelfKit
//
//  Created by Kei on 2026/11/07.
//

import Foundation

// 自前の書籍検索API（Cloudflare Workers の book-api）のレスポンスの形。
// 項目名は Worker 側の src/types.ts と一致させる。JSON にあってここに書いていない項目（sources など）は読み飛ばされる。

/// 本1冊（Worker の Book 型）。
struct BookAPIBookDTO: Decodable, Sendable {
  let isbn13: String
  let title: String
  let titleKana: String?
  let authors: [String]
  let publisher: String?
  let publishedDate: String?
  let pageCount: Int?
  let coverImageURL: String?
  let price: Int?
  let rakutenURL: String?
  let source: String
}

/// 外部APIごとの、そのリクエストでの状態。"ok" / "skipped" / "error" / "disabled" のどれか。
struct BookAPISourcesDTO: Decodable, Sendable {
    let ndl: String
    let rakuten: String
}

/// GET /v1/books/search のレスポンス
struct BookAPISearchResponseDTO: Decodable, Sendable {
  let books: [BookAPIBookDTO]
  let page: Int
  let hasMore: Bool
  let sources: BookAPISourcesDTO
}

/// GET /v1/books/isbn/{isbn} のレスポンス
struct BookAPIBookResponseDTO: Decodable, Sendable {
  let book: BookAPIBookDTO
  let sources: BookAPISourcesDTO
}

/// エラー時のレスポンス
struct BookAPIErrorBodyDTO: Decodable, Sendable {
  let error: String?
  let message: String?
}
