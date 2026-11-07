import Foundation
import Domain

public struct GoogleBooksCatalogRepository: BookCatalogRepository {
    private let client: GoogleBooksClient
    private let preferences: SearchPreferenceRepository
    private let pageSize = 20

    public init(client: GoogleBooksClient, preferences: SearchPreferenceRepository) {
        self.client = client
        self.preferences = preferences
    }

    /// キーワード検索。ISBN 判定による切替は Application 層の UseCase が担う。
    public func search(keyword: String, page: Int) async throws -> CatalogSearchResult {
        let lang = preferences.restrictToJapanese() ? "ja" : nil
        let dto = try await client.volumes(
            query: keyword,
            startIndex: page * pageSize,
            maxResults: pageSize,
            langRestrict: lang
        )
        return GoogleBooksMapper.toCatalogSearchResult(dto, page: page)
    }

    /// ISBN 検索。ISBN-13 で 0 件なら 978 プレフィックスを削って ISBN-10 で再検索する（Notion 04）。
    public func find(isbn: ISBN) async throws -> CatalogBook? {
        if let book = try await find(query: "isbn:\(isbn.value)") {
            return book
        }
        guard let isbn10 = ISBNConverter.toISBN10(isbn13: isbn.value) else {
            return nil
        }
        return try await find(query: "isbn:\(isbn10)")
    }

    private func find(query: String) async throws -> CatalogBook? {
        let dto = try await client.volumes(
            query: query,
            startIndex: 0,
            maxResults: 1,
            langRestrict: nil
        )
        return (dto.items ?? []).lazy.compactMap(GoogleBooksMapper.toCatalogBook).first
    }
}

enum ISBNConverter {
    /// ISBN-13 の 978 プレフィックスを ISBN-10 に戻す。それ以外は nil。
    static func toISBN10(isbn13: String) -> String? {
        guard isbn13.count == 13, isbn13.hasPrefix("978") else { return nil }
        let core = isbn13.dropFirst(3).dropLast()
        guard core.count == 9, core.allSatisfy({ $0.isNumber }) else { return nil }
        var sum = 0
        for (i, ch) in core.enumerated() {
            let digit = ch.wholeNumberValue ?? 0
            sum += (10 - i) * digit
        }
        let check = (11 - sum % 11) % 11
        return core + (check == 10 ? "X" : String(check))
    }
}
