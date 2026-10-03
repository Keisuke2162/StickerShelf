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

    @Test func pileToReading_reassignsBoardToReadingShelf() async throws {
        // 積読の本（pileFolder 所属）を「読み始める」で reading に遷移 → 本棚側の「読んでる」Board に自動割当。
        let now = Date()
        let pileFolderID = BoardID()
        let readingShelf = try Board(kind: .shelf, name: "読んでる", createdAt: now, sortOrder: 1)
        let finishedShelf = try Board(kind: .shelf, name: "読んだ", createdAt: now, sortOrder: 2)
        let pileFolder = try Board(id: pileFolderID, kind: .pile, name: "あとで読む", createdAt: now, sortOrder: 3)
        let boards = InMemoryBoardRepository([readingShelf, finishedShelf, pileFolder])

        let book = try Book(metadata: try BookMetadata(title: "本"), status: .unread, boardID: pileFolderID, addedAt: now)
        let bookRepo = InMemoryBookRepository([book])
        let useCase = ChangeReadingStatusUseCase(books: bookRepo, shelfResolver: ShelfBoardResolver(boards: boards))

        let updated = try await useCase.execute(id: book.id, newStatus: .reading, now: now)
        #expect(updated.status == .reading)
        #expect(updated.boardID == readingShelf.id)
    }

    @Test func pileToFinished_reassignsBoardToFinishedShelf() async throws {
        let now = Date()
        let readingShelf = try Board(kind: .shelf, name: "読んでる", createdAt: now, sortOrder: 1)
        let finishedShelf = try Board(kind: .shelf, name: "読んだ", createdAt: now, sortOrder: 2)
        let boards = InMemoryBoardRepository([readingShelf, finishedShelf])

        let book = try Book(metadata: try BookMetadata(title: "本"), status: .unread, addedAt: now)
        let bookRepo = InMemoryBookRepository([book])
        let useCase = ChangeReadingStatusUseCase(books: bookRepo, shelfResolver: ShelfBoardResolver(boards: boards))

        let updated = try await useCase.execute(id: book.id, newStatus: .finished, now: now)
        #expect(updated.status == .finished)
        #expect(updated.boardID == finishedShelf.id)
    }

    @Test func readingShelfBoardIsKept_whenAlreadyAssigned() async throws {
        // 既に shelf 側の Board に属している reading 本の boardID はそのまま尊重。
        let now = Date()
        let readingShelf = try Board(kind: .shelf, name: "読んでる", createdAt: now, sortOrder: 1)
        let customShelf = try Board(kind: .shelf, name: "お気に入り", createdAt: now, sortOrder: 2)
        let boards = InMemoryBoardRepository([readingShelf, customShelf])

        let book = try Book(
            metadata: try BookMetadata(title: "本"),
            status: .reading,
            period: ReadingPeriod(startedAt: now),
            sticker: .init(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1),
            boardID: customShelf.id,
            addedAt: now
        )
        let bookRepo = InMemoryBookRepository([book])
        let useCase = ChangeReadingStatusUseCase(books: bookRepo, shelfResolver: ShelfBoardResolver(boards: boards))

        let updated = try await useCase.execute(id: book.id, newStatus: .finished, now: now)
        #expect(updated.boardID == customShelf.id)
    }
}
