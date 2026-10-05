import Foundation

/// カレンダー画面に出すための「読んだ日」集計サービス。
/// `Book.readDays`（「読んだ」ボタンのログ）を日付ごとに集約する。
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

    /// 指定年月の「読んだ日」集計。
    /// 1 冊が同月内の複数日に記録されていれば複数日に出現し、月/年の冊数も重複カウントする
    /// （カレンダー上で「その日に読んだ本の冊数」を表示する用途に合わせる）。
    public func summary(books: [Book], year: Int, month: Int) -> MonthSummary {
        var grouped: [Date: [Book]] = [:]
        var monthCount = 0
        var yearCount = 0

        for book in books {
            for rawDate in book.readDays {
                let day = calendar.startOfDay(for: rawDate)
                let comps = calendar.dateComponents([.year, .month], from: day)
                guard let y = comps.year, let m = comps.month else { continue }
                if y == year {
                    yearCount += 1
                    if m == month {
                        monthCount += 1
                        grouped[day, default: []].append(book)
                    }
                }
            }
        }

        for key in grouped.keys {
            grouped[key]?.sort { $0.metadata.title < $1.metadata.title }
        }

        return MonthSummary(year: year, month: month, booksByDay: grouped, monthCount: monthCount, yearCount: yearCount)
    }
}
