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

    public func find(isbn: ISBN) async throws -> CatalogBook? {
        let dto = try await client.volumes(
            query: "isbn:\(isbn.value)",
            startIndex: 0,
            maxResults: 1,
            langRestrict: nil
        )
        return (dto.items ?? []).lazy.compactMap(GoogleBooksMapper.toCatalogBook).first
    }
}
