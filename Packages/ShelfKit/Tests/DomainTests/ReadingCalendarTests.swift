import Testing
import Foundation
@testable import Domain

@Suite("ReadingCalendar")
struct ReadingCalendarTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return c
    }()

    private func finishedBook(on date: Date, title: String) throws -> Book {
        let meta = try BookMetadata(title: title)
        let sticker = StickerPlacement(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1)
        var book = try Book(metadata: meta, status: .finished, period: ReadingPeriod(startedAt: date, finishedAt: date), sticker: sticker, addedAt: date)
        try book.updatePeriod(startedAt: date, finishedAt: date)
        return book
    }

    @Test func groupsByDay_andCountsMonthAndYear() throws {
        let d1 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let d2 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let d3 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let d4 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!
        let d5 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 31))!
        let books = [
            try finishedBook(on: d1, title: "A"),
            try finishedBook(on: d2, title: "B"),
            try finishedBook(on: d3, title: "C"),
            try finishedBook(on: d4, title: "D"),
            try finishedBook(on: d5, title: "E"),
        ]
        let summary = ReadingCalendar(calendar: calendar).summary(books: books, year: 2026, month: 10)
        #expect(summary.monthCount == 3)
        #expect(summary.yearCount == 4)
        #expect(summary.booksByDay[calendar.startOfDay(for: d2)]?.count == 2)
        #expect(summary.booksByDay.count == 2)
    }

    @Test func ignoresUnfinishedBooks() throws {
        let d1 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let meta = try BookMetadata(title: "進行中")
        let sticker = StickerPlacement(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1)
        let book = try Book(metadata: meta, status: .reading, period: ReadingPeriod(startedAt: d1), sticker: sticker, addedAt: d1)
        let summary = ReadingCalendar(calendar: calendar).summary(books: [book], year: 2026, month: 10)
        #expect(summary.monthCount == 0)
        #expect(summary.booksByDay.isEmpty)
    }

    @Test func firstWeekdayIsSunday() {
        #expect(ReadingCalendar(calendar: calendar).calendar.firstWeekday == 1)
    }
}
