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
        let draft = BookDetailDraft(
            status: .reading,
            currentPage: 25,
            startedAt: now,
            finishedAt: nil,
            purchasedAt: now,
            purchasePlace: "書店",
            memo: "面白い",
            stickerEdge: .holo
        )
        let updated = try await useCase.execute(id: book.id, draft: draft, now: now)
        #expect(updated.status == .reading)
        #expect(updated.progress.currentPage == 25)
        #expect(updated.memo == "面白い")
        #expect(updated.stickerEdge == .holo)
        #expect(updated.sticker != nil)
    }

    @Test func rejectsInvalidPeriod() async throws {
        let now = Date()
        // 日単位で比較するので、1日以上離した未来日と現在日で invalid にする
        let laterDay = now.addingTimeInterval(60 * 60 * 24 * 2)
        let meta = try BookMetadata(title: "本")
        let book = try Book(metadata: meta, status: .unread, addedAt: now)
        let books = InMemoryBookRepository([book])
        let useCase = UpdateBookDetailUseCase(books: books)
        let draft = BookDetailDraft(status: .finished, currentPage: 0, startedAt: laterDay, finishedAt: now, purchasedAt: nil, purchasePlace: "", memo: "", stickerEdge: .white)
        await #expect(throws: DomainError.invalidPeriod) {
            _ = try await useCase.execute(id: book.id, draft: draft, now: now)
        }
    }
}
