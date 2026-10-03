import Testing
import Foundation
@testable import Application
@testable import Domain

@Suite("UpdateBookDetailUseCase")
struct UpdateBookDetailUseCaseTests {
    @Test func savesDraft_andTriggersStatusChange() async throws {
        let now = Date()
        let meta = try BookMetadata(title: "本", pageCount: 100)
        let book = try Book(metadata: meta, status: .unread, addedAt: now)
        let books = InMemoryBookRepository([book])
        let useCase = UpdateBookDetailUseCase(books: books)
        let boardID = BoardID()
        let draft = BookDetailDraft(
            status: .reading,
            finishedAt: nil,
            purchasedAt: now,
            stickerEdge: .holo,
            boardID: boardID
        )
        let updated = try await useCase.execute(id: book.id, draft: draft, now: now)
        #expect(updated.status == .reading)
        #expect(updated.stickerEdge == .holo)
        #expect(updated.sticker != nil)
        #expect(updated.boardID == boardID)
    }

    @Test func unreadDraftKeepsBoard() async throws {
        // 積読もフォルダ所属できる仕様 (2026-10-03) に変更。unread 遷移でも draft の boardID を保持する。
        let now = Date()
        let meta = try BookMetadata(title: "本")
        let sticker = StickerPlacement(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1)
        let shelfBoard = BoardID()
        let pileBoard = BoardID()
        let book = try Book(metadata: meta, status: .reading, period: ReadingPeriod(startedAt: now), sticker: sticker, boardID: shelfBoard, addedAt: now)
        let books = InMemoryBookRepository([book])
        let useCase = UpdateBookDetailUseCase(books: books)
        let draft = BookDetailDraft(status: .unread, finishedAt: nil, purchasedAt: nil, stickerEdge: .white, boardID: pileBoard)
        let updated = try await useCase.execute(id: book.id, draft: draft, now: now)
        #expect(updated.status == .unread)
        #expect(updated.boardID == pileBoard)
    }

    @Test func rejectsInvalidPeriod() async throws {
        let now = Date()
        let laterDay = now.addingTimeInterval(60 * 60 * 24 * 2)
        let meta = try BookMetadata(title: "本")
        let sticker = StickerPlacement(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1)
        // 既存書籍は startedAt=laterDay で reading。これで finished に遷移する際に finishedAt=now 未満になる。
        let book = try Book(metadata: meta, status: .reading, period: ReadingPeriod(startedAt: laterDay), sticker: sticker, addedAt: now)
        let books = InMemoryBookRepository([book])
        let useCase = UpdateBookDetailUseCase(books: books)
        let draft = BookDetailDraft(status: .finished, finishedAt: now, purchasedAt: nil, stickerEdge: .white, boardID: nil)
        await #expect(throws: DomainError.invalidPeriod) {
            _ = try await useCase.execute(id: book.id, draft: draft, now: now)
        }
    }
}
