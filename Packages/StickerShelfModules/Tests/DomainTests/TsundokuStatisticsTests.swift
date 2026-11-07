import Testing
import Foundation
@testable import Domain

@Suite("TsundokuStatistics")
struct TsundokuStatisticsTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return c
    }()

    private func makeBook(id: BookID = BookID(), status: ReadingStatus, purchasedAt: Date?, addedAt: Date) throws -> Book {
        let meta = try BookMetadata(title: "本")
        let sticker = status == .unread ? nil : StickerPlacement(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1)
        var book = try Book(id: id, metadata: meta, status: status, sticker: sticker, addedAt: addedAt)
        book.updatePurchase(PurchaseInfo(purchasedAt: purchasedAt))
        return book
    }

    @Test func countsOnlyUnread() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2))!
        let books = [
            try makeBook(status: .unread, purchasedAt: calendar.date(byAdding: .day, value: -10, to: now), addedAt: now),
            try makeBook(status: .reading, purchasedAt: now, addedAt: now),
            try makeBook(status: .unread, purchasedAt: calendar.date(byAdding: .day, value: -4, to: now), addedAt: now),
        ]
        let stat = TsundokuStatistics(calendar: calendar).snapshot(books: books, now: now)
        #expect(stat.count == 2)
        #expect(stat.averageDays == 7)
    }

    @Test func addedThisMonth() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let thisMonth = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        let lastMonth = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25))!
        let books = [
            try makeBook(status: .unread, purchasedAt: nil, addedAt: thisMonth),
            try makeBook(status: .unread, purchasedAt: nil, addedAt: lastMonth),
            try makeBook(status: .unread, purchasedAt: nil, addedAt: thisMonth),
        ]
        let stat = TsundokuStatistics(calendar: calendar).snapshot(books: books, now: now)
        #expect(stat.addedThisMonth == 2)
    }

    @Test func emptyGivesZeros() {
        let now = Date()
        let stat = TsundokuStatistics(calendar: calendar).snapshot(books: [], now: now)
        #expect(stat.count == 0)
        #expect(stat.averageDays == 0)
        #expect(stat.addedThisMonth == 0)
    }

    @Test func averageDays_usesAddedAtWhenPurchasedAtIsNil() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11))!
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: now)!
        let books = [try makeBook(status: .unread, purchasedAt: nil, addedAt: tenDaysAgo)]
        let stat = TsundokuStatistics(calendar: calendar).snapshot(books: books, now: now)
        #expect(stat.averageDays == 10)
    }

    @Test func addedThisMonth_countsAllStatuses() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let thisMonth = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        let books = [
            try makeBook(status: .unread, purchasedAt: nil, addedAt: thisMonth),
            try makeBook(status: .reading, purchasedAt: nil, addedAt: thisMonth),
            try makeBook(status: .finished, purchasedAt: nil, addedAt: thisMonth),
        ]
        let stat = TsundokuStatistics(calendar: calendar).snapshot(books: books, now: now)
        #expect(stat.addedThisMonth == 3)
    }
}
