import Testing
import Foundation
@testable import Application
@testable import Domain

@Suite("ChangeReadingStatusUseCase")
struct ChangeReadingStatusUseCaseTests {
    @Test func movesUnreadToReading_assignsStickerAndStart() async throws {
        let meta = try BookMetadata(title: "積読")
        let book = try Book(metadata: meta, status: .unread, addedAt: Date())
        let books = InMemoryBookRepository([book])
        let useCase = ChangeReadingStatusUseCase(books: books)
        let now = Date()
        let updated = try await useCase.execute(id: book.id, newStatus: .reading, now: now)
        #expect(updated.status == .reading)
        #expect(updated.sticker != nil)
        #expect(updated.period.startedAt == now)
    }

    @Test func movesReadingToUnread_clearsEverything() async throws {
        let meta = try BookMetadata(title: "読書中")
        let now = Date()
        let book = try Book(metadata: meta, status: .reading, period: ReadingPeriod(startedAt: now), sticker: .init(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1), addedAt: now)
        let books = InMemoryBookRepository([book])
        let useCase = ChangeReadingStatusUseCase(books: books)
        let updated = try await useCase.execute(id: book.id, newStatus: .unread, now: now)
        #expect(updated.status == .unread)
        #expect(updated.sticker == nil)
        #expect(updated.period.startedAt == nil)
    }
}
