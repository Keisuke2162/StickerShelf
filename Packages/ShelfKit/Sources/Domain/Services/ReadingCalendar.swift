import Foundation

/// カレンダー画面に出すための読了本集計サービス。
public struct ReadingCalendar: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        var cal = calendar
        cal.firstWeekday = 1 // 日曜始まり
        self.calendar = cal
    }

    public struct MonthSummary: Equatable, Sendable {
        public let year: Int
        public let month: Int
        public let booksByDay: [Date: [Book]]
        public let monthCount: Int
        public let yearCount: Int

        public init(year: Int, month: Int, booksByDay: [Date: [Book]], monthCount: Int, yearCount: Int) {
            self.year = year
            self.month = month
            self.booksByDay = booksByDay
            self.monthCount = monthCount
            self.yearCount = yearCount
        }
    }

    public func summary(books: [Book], year: Int, month: Int) -> MonthSummary {
        let finished = books.filter { $0.status == .finished && $0.period.finishedAt != nil }

        var grouped: [Date: [Book]] = [:]
        var monthCount = 0
        var yearCount = 0

        for book in finished {
            guard let date = book.period.finishedAt else { continue }
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            guard let y = comps.year, let m = comps.month, let _ = comps.day else { continue }
            if y == year {
                yearCount += 1
                if m == month {
                    monthCount += 1
                    let day = calendar.startOfDay(for: date)
                    grouped[day, default: []].append(book)
                }
            }
        }

        for key in grouped.keys {
            grouped[key]?.sort { ($0.period.finishedAt ?? .distantPast) < ($1.period.finishedAt ?? .distantPast) }
        }

        return MonthSummary(year: year, month: month, booksByDay: grouped, monthCount: monthCount, yearCount: yearCount)
    }
}
