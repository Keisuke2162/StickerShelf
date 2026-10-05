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

    private func readingBook(title: String, readOn dates: [Date]) throws -> Book {
        let meta = try BookMetadata(title: title)
        let sticker = StickerPlacement(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1)
        var book = try Book(metadata: meta, status: .reading, period: ReadingPeriod(startedAt: dates.first), sticker: sticker, addedAt: dates.first ?? Date())
        for d in dates { book.markAsRead(on: d, calendar: calendar) }
        return book
    }

    @Test func groupsByDay_andCountsMonthAndYear() throws {
        let d1 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let d2 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let d4 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!
        let d5 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 31))!
        let books = [
            try readingBook(title: "A", readOn: [d1]),
            try readingBook(title: "B", readOn: [d2]),
            try readingBook(title: "C", readOn: [d2]),
            try readingBook(title: "D", readOn: [d4]),
            try readingBook(title: "E", readOn: [d5]),
        ]
        let summary = ReadingCalendar(calendar: calendar).summary(books: books, year: 2026, month: 10)
        #expect(summary.monthCount == 3)
        #expect(summary.yearCount == 4)
        #expect(summary.booksByDay[calendar.startOfDay(for: d2)]?.count == 2)
        #expect(summary.booksByDay.count == 2)
    }

    @Test func sameBookMultipleDays_countsPerDay() throws {
        // 同じ本を複数日に「読んだ」記録 → 日毎にそれぞれ 1 件ずつ出現、月/年の冊数も重複カウント。
        let d1 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        let d2 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7))!
        let book = try readingBook(title: "連日読書", readOn: [d1, d2])
        let summary = ReadingCalendar(calendar: calendar).summary(books: [book], year: 2026, month: 10)
        #expect(summary.monthCount == 2)
        #expect(summary.booksByDay.count == 2)
        #expect(summary.booksByDay[calendar.startOfDay(for: d1)]?.count == 1)
        #expect(summary.booksByDay[calendar.startOfDay(for: d2)]?.count == 1)
    }

    @Test func ignoresBooksWithoutReadDays() throws {
        let d1 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let meta = try BookMetadata(title: "記録なし")
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
