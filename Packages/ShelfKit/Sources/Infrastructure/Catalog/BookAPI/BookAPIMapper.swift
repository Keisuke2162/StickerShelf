//
//  BookAPIMapper.swift
//  ShelfKit
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
    
    // BookMetadataは初期化時にtitleが空, pageCountが0だとthrowする仕様なのでtry
    guard let metadata = try? BookMetadata(
      title: dto.title,
      authors: dto.authors,
      publisher: dto.publisher,
      publishedDate: dto.publishedDate,
      pageCount: pageCount,
      isbn: isbn,
      remoteCoverURL: coverURL,
      
      // 【暫定】Google Books 用の項目。5-11 で catalogID 自体を消し、CatalogBook の ISBN で見分ける形に置き換える
      catalogID: isbn.value
    ) else { return nil }
    return CatalogBook(metadata: metadata)
  }
  
  /// 検索結果を CatalogSearchResult にする。
  /// 【暫定】Domain がまだ Google Books 用の totalItems を持つので、このページの件数を入れる。5-11 で hasMore に置き換える。
  static func toCatalogSearchResult(_ dto: BookAPISearchResponseDTO, page: Int) -> CatalogSearchResult {
    let books = dto.books.compactMap(toCatalogBook)
    return CatalogSearchResult(books: books, totalItems: books.count, page: page)
  }
}
