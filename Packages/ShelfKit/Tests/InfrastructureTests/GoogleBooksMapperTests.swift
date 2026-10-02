import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("GoogleBooksMapper")
struct GoogleBooksMapperTests {
    @Test func mapsSubtitleIntoTitle_andNormalizesCoverURL() throws {
        let data = try FixtureLoader.data("volumes_search_normal")
        let dto = try JSONDecoder().decode(GoogleBooksVolumesResponseDTO.self, from: data)
        let result = GoogleBooksMapper.toCatalogSearchResult(dto, page: 0)
        #expect(result.totalItems == 2)
        #expect(result.books.count == 2)
        let first = result.books[0]
        #expect(first.metadata.title == "宇宙 はじめての観測")
        #expect(first.metadata.authors == ["山田太郎", "鈴木花子"])
        #expect(first.metadata.publisher == "星屑出版")
        #expect(first.metadata.pageCount == 320)
        #expect(first.metadata.isbn?.value == "9784101010014")
        #expect(first.metadata.remoteCoverURL?.scheme == "https")
        #expect(first.metadata.remoteCoverURL?.absoluteString.contains("edge=curl") == false)
    }

    @Test func excludesPageCountZero_andFallsBackToISBN10() throws {
        let data = try FixtureLoader.data("volumes_search_normal")
        let dto = try JSONDecoder().decode(GoogleBooksVolumesResponseDTO.self, from: data)
        let result = GoogleBooksMapper.toCatalogSearchResult(dto, page: 0)
        let second = result.books[1]
        #expect(second.metadata.pageCount == nil)
        #expect(second.metadata.authors.isEmpty)
        #expect(second.metadata.isbn?.value == "9784101010014")
    }

    @Test func emptyResponse() throws {
        let data = try FixtureLoader.data("volumes_empty")
        let dto = try JSONDecoder().decode(GoogleBooksVolumesResponseDTO.self, from: data)
        let result = GoogleBooksMapper.toCatalogSearchResult(dto, page: 2)
        #expect(result.totalItems == 0)
        #expect(result.books.isEmpty)
        #expect(result.page == 2)
    }

    @Test func mapsISBN10OnlyVolume() throws {
        let data = try FixtureLoader.data("volumes_isbn10_only")
        let dto = try JSONDecoder().decode(GoogleBooksVolumesResponseDTO.self, from: data)
        let result = GoogleBooksMapper.toCatalogSearchResult(dto, page: 0)
        #expect(result.books.first?.metadata.isbn?.value == "9784101010014")
    }
}
