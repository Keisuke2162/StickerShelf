import Testing
import Foundation
import SwiftData
@testable import Infrastructure
@testable import Domain

@Suite("SwiftDataBookRepository")
struct SwiftDataBookRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([BookRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeBook(title: String = "テスト", status: ReadingStatus = .unread, isbn: ISBN? = nil, sticker: StickerPlacement? = nil) throws -> Book {
        let meta = try BookMetadata(title: title, isbn: isbn)
        let effectiveSticker: StickerPlacement? = status == .unread ? nil : (sticker ?? StickerPlacement(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1))
        return try Book(metadata: meta, status: status, sticker: effectiveSticker, addedAt: Date())
    }

    @Test func saveThenFetchRoundTrip() async throws {
        let container = try makeContainer()
        let repo = SwiftDataBookRepository(modelContainer: container)
        let book = try makeBook(title: "ラウンドトリップ", isbn: ISBN("9784101010014"))
        try await repo.save(book)
        let loaded = try await repo.fetch(id: book.id)
        #expect(loaded != nil)
        #expect(loaded?.metadata.title == "ラウンドトリップ")
        #expect(loaded?.metadata.isbn?.value == "9784101010014")
    }

    @Test func fetchByStatusFilters() async throws {
        let container = try makeContainer()
        let repo = SwiftDataBookRepository(modelContainer: container)
        try await repo.save(try makeBook(title: "積読A"))
        try await repo.save(try makeBook(title: "読書中B", status: .reading))
        try await repo.save(try makeBook(title: "読了C", status: .finished))

        let unreadOnly = try await repo.fetch(status: [.unread])
        #expect(unreadOnly.count == 1)
        #expect(unreadOnly.first?.metadata.title == "積読A")

        let onShelf = try await repo.fetch(status: [.reading, .finished])
        #expect(onShelf.count == 2)
    }

    @Test func fetchFinishedInInterval() async throws {
        let container = try makeContainer()
        let repo = SwiftDataBookRepository(modelContainer: container)
        var finishedInRange = try makeBook(title: "期間内", status: .finished)
        try finishedInRange.updatePeriod(startedAt: Date(timeIntervalSince1970: 1_770_000_000), finishedAt: Date(timeIntervalSince1970: 1_770_000_000))
        try await repo.save(finishedInRange)

        let interval = DateInterval(start: Date(timeIntervalSince1970: 1_769_000_000), end: Date(timeIntervalSince1970: 1_771_000_000))
        let books = try await repo.fetchFinished(in: interval)
        #expect(books.count == 1)
    }

    @Test func deleteRemovesRecord() async throws {
        let container = try makeContainer()
        let repo = SwiftDataBookRepository(modelContainer: container)
        let book = try makeBook(title: "削除対象")
        try await repo.save(book)
        try await repo.delete(id: book.id)
        let loaded = try await repo.fetch(id: book.id)
        #expect(loaded == nil)
    }

    @Test func fetchByISBN() async throws {
        let container = try makeContainer()
        let repo = SwiftDataBookRepository(modelContainer: container)
        let isbn = ISBN("9784101010014")!
        let book = try makeBook(title: "ISBN検索", isbn: isbn)
        try await repo.save(book)
        let loaded = try await repo.fetch(isbn: isbn)
        #expect(loaded?.id == book.id)
    }
}
