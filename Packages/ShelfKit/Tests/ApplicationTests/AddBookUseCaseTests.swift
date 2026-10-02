import Testing
import Foundation
@testable import Application
@testable import Domain

@Suite("AddBookUseCase")
struct AddBookUseCaseTests {
    @Test func addsFromCatalogAsUnread() async throws {
        let books = InMemoryBookRepository()
        let useCase = AddBookUseCase(books: books)
        let meta = try BookMetadata(title: "宇宙", isbn: ISBN("9784101010014"))
        let input = AddBookInput(source: .catalog(CatalogBook(metadata: meta)), initialStatus: .unread, purchasedAt: Date(), now: Date())
        let book = try await useCase.execute(input)
        #expect(book.status == .unread)
        #expect(book.sticker == nil)
        #expect(book.purchase.purchasedAt != nil)
        #expect(try await books.fetchAll().count == 1)
    }

    @Test func addsAsReading_assignsSticker_andStartedAt() async throws {
        let books = InMemoryBookRepository()
        let useCase = AddBookUseCase(books: books)
        let meta = try BookMetadata(title: "宇宙")
        let now = Date()
        let input = AddBookInput(source: .catalog(CatalogBook(metadata: meta)), initialStatus: .reading, purchasedAt: nil, now: now)
        let book = try await useCase.execute(input)
        #expect(book.status == .reading)
        #expect(book.sticker != nil)
        #expect(book.period.startedAt == now)
    }

    @Test func rejectsDuplicateISBN() async throws {
        let books = InMemoryBookRepository()
        let useCase = AddBookUseCase(books: books)
        let isbn = ISBN("9784101010014")!
        let meta = try BookMetadata(title: "宇宙", isbn: isbn)
        let input = AddBookInput(source: .catalog(CatalogBook(metadata: meta)), initialStatus: .unread, purchasedAt: nil, now: Date())
        _ = try await useCase.execute(input)
        await #expect(throws: (any Error).self) {
            _ = try await useCase.execute(input)
        }
    }

    @Test func manualEntryRequiresTitle() async throws {
        let books = InMemoryBookRepository()
        let useCase = AddBookUseCase(books: books)
        let bad = AddBookInput.ManualEntry(title: "   ")
        let input = AddBookInput(source: .manual(bad), initialStatus: .unread, purchasedAt: nil, now: Date())
        await #expect(throws: DomainError.invalidTitle) {
            _ = try await useCase.execute(input)
        }
    }
}
