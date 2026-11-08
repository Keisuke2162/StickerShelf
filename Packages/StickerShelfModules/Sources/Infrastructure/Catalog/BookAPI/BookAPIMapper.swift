//
//  BookAPIMapper.swift
//  Infrastructure
//
//  Created by Kei on 2026/11/07.
//

import Foundation
import Domain

/// 自前APIのレスポンス（DTO）を、アプリの Domain の型（CatalogBook）に変換する。
enum BookAPIMapper {
  /// 本1冊を CatalogBook にする。ISBN やタイトルが不正な本は nil（一覧から外す）。
  static func toCatalogBook(_ dto: BookAPIBookDTO) -> CatalogBook? {
    // API は必ず 13桁の ISBN を返すが、念のため Domain の ISBN 型で検証する
    guard let isbn = ISBN(dto.isbn13) else { return nil }
    
    // ページ数 0 以下は BookMetadata が受け付けないので「不明」にする
    let pageCount: Int? = (dto.pageCount ?? 0) > 0 ? dto.pageCount : nil
    let coverURL: URL? = dto.coverImageURL.flatMap { URL(string: $0) }
    
    // BookMetadata はタイトルが空、ページ数が 0 以下だと throw する。try? で失敗を nil にして、その本だけ外す
    guard let metadata = try? BookMetadata(
      title: dto.title,
      authors: dto.authors,
      publisher: dto.publisher,
      publishedDate: dto.publishedDate,
      pageCount: pageCount,
      isbn: isbn,
      remoteCoverURL: coverURL
    ) else { return nil }
    // ISBN を渡しているので、CatalogBook の初期化は失敗しない
    return try? CatalogBook(metadata: metadata)
  }
  
  /// 検索結果を CatalogSearchResult にする。page はアプリ側の 0 始まりの値
  static func toCatalogSearchResult(_ dto: BookAPISearchResponseDTO, page: Int) -> CatalogSearchResult {
    CatalogSearchResult(books: dto.books.compactMap(toCatalogBook), hasMore: dto.hasMore, page: page)
  }
}
