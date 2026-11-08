import Testing
import Foundation
@testable import Domain

@Suite("Book のステータス遷移")
struct BookStatusTransitionTests {
    let today = Date(timeIntervalSince1970: 1_770_000_000) // 2026-02-02
    let placement = StickerPlacement(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1)

    private func makeBook(status: ReadingStatus = .unread, pageCount: Int? = nil, period: ReadingPeriod = .init(), sticker: StickerPlacement? = nil) throws -> Book {
        let meta = try BookMetadata(title: "テスト", pageCount: pageCount)
        let effectiveSticker = status == .unread ? nil : (sticker ?? placement)
        return try Book(metadata: meta, status: status, period: period, sticker: effectiveSticker, addedAt: today)
    }

    @Test func unreadToReading_setsStartedAt_andAssignsSticker() throws {
        var book = try makeBook()
        try book.changeStatus(to: .reading, on: today) { placement }
        #expect(book.status == .reading)
        #expect(book.period.startedAt == today)
        #expect(book.sticker == placement)
    }

    @Test func unreadToFinished_setsBothDates_andProgressFull() throws {
        var book = try makeBook(pageCount: 280)
        try book.changeStatus(to: .finished, on: today) { placement }
        #expect(book.status == .finished)
        #expect(book.period.finishedAt == today)
        #expect(book.period.startedAt == today)
        #expect(book.progress.currentPage == 280)
        #expect(book.sticker == placement)
    }

    @Test func readingToUnread_clearsPeriodAndSticker() throws {
        var book = try makeBook()
        try book.changeStatus(to: .reading, on: today) { placement }
        try book.changeStatus(to: .unread, on: today) { placement }
        #expect(book.status == .unread)
        #expect(book.period.startedAt == nil)
        #expect(book.period.finishedAt == nil)
        #expect(book.sticker == nil)
        #expect(book.progress.currentPage == 0)
    }

    @Test func readingToFinished_keepsExistingStart_setsFinish() throws {
        var book = try makeBook()
        try book.changeStatus(to: .reading, on: today) { placement }
        let threeDaysLater = today.addingTimeInterval(60 * 60 * 24 * 3)
        try book.changeStatus(to: .finished, on: threeDaysLater) { placement }
        #expect(book.period.startedAt == today)
        #expect(book.period.finishedAt == threeDaysLater)
    }

    @Test func updatePeriod_rejectsFinishBeforeStart() throws {
        var book = try makeBook()
        let later = today
        let earlier = today.addingTimeInterval(-60 * 60 * 24)
        #expect(throws: DomainError.invalidPeriod) {
            try book.updatePeriod(startedAt: later, finishedAt: earlier)
        }
    }

    @Test func updateProgress_rejectsOverflow() throws {
        var book = try makeBook(pageCount: 100)
        #expect(throws: DomainError.pageOutOfRange) {
            try book.updateProgress(currentPage: 101)
        }
    }

    @Test func updateProgress_rejectsNegative() throws {
        var book = try makeBook(pageCount: 100)
        #expect(throws: DomainError.pageOutOfRange) {
            try book.updateProgress(currentPage: -1)
        }
    }

    @Test func moveSticker_requiresNotUnread() throws {
        var book = try makeBook()
        #expect(throws: DomainError.stickerNotAllowedForUnread) {
            try book.moveSticker(to: placement)
        }
    }

    @Test func unreadToReadingToUnread_toFinishedAgain_assignsNewSticker() throws {
        var book = try makeBook()
        try book.changeStatus(to: .reading, on: today) { placement }
        try book.changeStatus(to: .unread, on: today) { placement }
        var called = false
        let newPlacement = StickerPlacement(x: 0.3, y: 0.3, rotationDegrees: 5, scale: 1, zIndex: 2)
        try book.changeStatus(to: .finished, on: today) {
            called = true
            return newPlacement
        }
        #expect(called)
        #expect(book.sticker == newPlacement)
    }

    // --- 追加分（レビュー指摘） ---

    @Test func finishedToReading_keepsStickerAndStart_clearsFinishIsNotRequired() throws {
        var book = try makeBook()
        try book.changeStatus(to: .finished, on: today) { placement }
        let originalFinished = book.period.finishedAt
        let twoDaysLater = today.addingTimeInterval(60 * 60 * 24 * 2)
        try book.changeStatus(to: .reading, on: twoDaysLater) { placement }
        #expect(book.status == .reading)
        #expect(book.period.startedAt == today) // 保持
        #expect(book.period.finishedAt == originalFinished) // ← 自動補完は無く、保持（検証通る）
        #expect(book.sticker != nil) // 本棚上の book は sticker を保つ
    }

    @Test func finishedToUnread_clearsEverything() throws {
        var book = try makeBook(pageCount: 100)
        try book.changeStatus(to: .finished, on: today) { placement }
        #expect(book.progress.currentPage == 100)
        try book.changeStatus(to: .unread, on: today) { placement }
        #expect(book.status == .unread)
        #expect(book.period.startedAt == nil)
        #expect(book.period.finishedAt == nil)
        #expect(book.sticker == nil)
        #expect(book.progress.currentPage == 0)
    }

    @Test func readingToFinished_whenStartIsInFuture_throwsAndKeepsStatus() throws {
        // startedAt が今日より未来 → finishedAt=today を自動補完すると invalidPeriod
        let futureStart = today.addingTimeInterval(60 * 60 * 24 * 5)
        var book = try makeBook(status: .reading, period: ReadingPeriod(startedAt: futureStart, finishedAt: nil))
        #expect(throws: DomainError.invalidPeriod) {
            try book.changeStatus(to: .finished, on: today) { placement }
        }
        // 失敗後に status が reading のままであること（副作用なし）
        #expect(book.status == .reading)
        #expect(book.period.startedAt == futureStart)
        #expect(book.period.finishedAt == nil)
    }

    @Test func unreadToFinished_withNilPageCount_doesNotTouchProgress() throws {
        var book = try makeBook(pageCount: nil)
        #expect(book.progress.currentPage == 0)
        try book.changeStatus(to: .finished, on: today) { placement }
        #expect(book.progress.currentPage == 0)
    }

    @Test func moveSticker_succeedsOnReading() throws {
        var book = try makeBook()
        try book.changeStatus(to: .reading, on: today) { placement }
        let newPlacement = StickerPlacement(x: 0.1, y: 0.1, rotationDegrees: 10, scale: 1.2, zIndex: 9)
        try book.moveSticker(to: newPlacement)
        #expect(book.sticker == newPlacement)
    }

    @Test func unreadInitWithStickerIsRejected() throws {
        let meta = try BookMetadata(title: "だめな本")
        #expect(throws: DomainError.stickerNotAllowedForUnread) {
            _ = try Book(metadata: meta, status: .unread, sticker: placement, addedAt: today)
        }
    }

    @Test func readingInitWithoutStickerIsRejected() throws {
        let meta = try BookMetadata(title: "だめな本")
        #expect(throws: DomainError.stickerNotAllowedForUnread) {
            _ = try Book(metadata: meta, status: .reading, sticker: nil, addedAt: today)
        }
    }
}
