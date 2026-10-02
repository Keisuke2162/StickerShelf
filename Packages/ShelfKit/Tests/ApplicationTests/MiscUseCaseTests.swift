import Testing
import Foundation
@testable import Application
@testable import Domain

@Suite("小ぶりな UseCase 群")
struct MiscUseCaseTests {
    @Test func findCatalogBookByISBN_delegatesToCatalog() async throws {
        let catalog = StubCatalogRepository()
        let meta = try BookMetadata(title: "見つけた", isbn: ISBN("9784101010014"))
        catalog.findResult = .success(CatalogBook(metadata: meta))
        let useCase = FindCatalogBookByISBNUseCase(catalog: catalog)
        let book = try await useCase.execute(isbn: ISBN("9784101010014")!)
        #expect(book?.metadata.title == "見つけた")
    }

    @Test func fetchShelf_sortsByZIndexAscending_filteredByBoard() async throws {
        let now = Date()
        let boardA = BoardID()
        let boardB = BoardID()
        let a = try Book(metadata: try BookMetadata(title: "A"), status: .reading, sticker: .init(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 5), boardID: boardA, addedAt: now)
        let b = try Book(metadata: try BookMetadata(title: "B"), status: .finished, period: ReadingPeriod(startedAt: now, finishedAt: now), sticker: .init(x: 0.4, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1), boardID: boardA, addedAt: now)
        let c = try Book(metadata: try BookMetadata(title: "別ボード"), status: .reading, sticker: .init(x: 0.3, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 2), boardID: boardB, addedAt: now)
        let repo = InMemoryBookRepository([a, b, c])
        let useCase = FetchShelfUseCase(books: repo)
        let out = try await useCase.execute(boardID: boardA)
        #expect(out.books.map(\.metadata.title) == ["B", "A"])
    }

    @Test func fetchReadingCalendar_delegatesToReadingCalendar() async throws {
        let cal = Calendar(identifier: .gregorian)
        let date = cal.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let book = try Book(
            metadata: try BookMetadata(title: "完了"),
            status: .finished,
            period: ReadingPeriod(startedAt: date, finishedAt: date),
            sticker: .init(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1),
            addedAt: date
        )
        let repo = InMemoryBookRepository([book])
        let useCase = FetchReadingCalendarUseCase(books: repo, calendar: ReadingCalendar(calendar: cal))
        let summary = try await useCase.execute(year: 2026, month: 10)
        #expect(summary.monthCount == 1)
    }

    @Test func fetchBookDetail() async throws {
        let book = try Book(metadata: try BookMetadata(title: "詳細"), status: .unread, addedAt: Date())
        let repo = InMemoryBookRepository([book])
        let useCase = FetchBookDetailUseCase(books: repo)
        let fetched = try await useCase.execute(id: book.id)
        #expect(fetched?.metadata.title == "詳細")
    }

    @Test func moveSticker_rejectsUnread() async throws {
        let book = try Book(metadata: try BookMetadata(title: "積読"), status: .unread, addedAt: Date())
        let repo = InMemoryBookRepository([book])
        let useCase = MoveStickerUseCase(books: repo)
        await #expect(throws: DomainError.stickerNotAllowedForUnread) {
            try await useCase.execute(id: book.id, placement: .init(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1))
        }
    }

    @Test func replaceCover_deletesOldLocal() async throws {
        let oldCover = CoverImage.local(fileName: "old.jpg")
        let book = try Book(metadata: try BookMetadata(title: "本"), status: .unread, cover: oldCover, addedAt: Date())
        let repo = InMemoryBookRepository([book])
        let covers = InMemoryCoverImageRepository()
        let useCase = ReplaceCoverImageUseCase(books: repo, covers: covers)
        let updated = try await useCase.execute(id: book.id, imageData: Data([1, 2, 3]))
        if case .local = updated.cover {} else { Issue.record("expected local cover") }
        let deleted = await covers.deletedLocalFiles
        #expect(deleted.contains("old.jpg"))
    }

    @Test func deleteBook_removesStorage_andLocalFile() async throws {
        let cover = CoverImage.local(fileName: "img.jpg")
        let book = try Book(metadata: try BookMetadata(title: "削除"), status: .unread, cover: cover, addedAt: Date())
        let repo = InMemoryBookRepository([book])
        let covers = InMemoryCoverImageRepository()
        let useCase = DeleteBookUseCase(books: repo, covers: covers)
        try await useCase.execute(id: book.id)
        #expect(try await repo.fetch(id: book.id) == nil)
        let deleted = await covers.deletedLocalFiles
        #expect(deleted.contains("img.jpg"))
    }

    @Test func testCatalogConnection_mapsErrors() async {
        let catalog = StubCatalogRepository()
        catalog.findResult = .failure(DomainError.invalidAPIKey)
        var result = await TestCatalogConnectionUseCase(catalog: catalog).execute()
        #expect(result == .invalidAPIKey)

        catalog.findResult = .failure(DomainError.catalogQuotaExceeded)
        result = await TestCatalogConnectionUseCase(catalog: catalog).execute()
        #expect(result == .quotaExceeded)

        catalog.findResult = .failure(DomainError.network)
        result = await TestCatalogConnectionUseCase(catalog: catalog).execute()
        #expect(result == .networkUnavailable)

        catalog.findResult = .failure(DomainError.catalogUnavailable(reason: "500"))
        result = await TestCatalogConnectionUseCase(catalog: catalog).execute()
        #expect(result == .serviceUnavailable)

        catalog.findResult = .success(nil)
        result = await TestCatalogConnectionUseCase(catalog: catalog).execute()
        #expect(result == .success)
    }
}
