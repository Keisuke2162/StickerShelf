import Foundation

/// 積読の集計を計算する純関数的サービス。
public struct TsundokuStatistics: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public struct Snapshot: Equatable, Sendable {
        public let count: Int
        public let averageDays: Int
        public let addedThisMonth: Int

        public init(count: Int, averageDays: Int, addedThisMonth: Int) {
            self.count = count
            self.averageDays = averageDays
            self.addedThisMonth = addedThisMonth
        }
    }

    public func snapshot(books: [Book], now: Date) -> Snapshot {
        let unread = books.filter { $0.status == .unread }
        let count = unread.count

        let today = calendar.startOfDay(for: now)
        let daysList: [Int] = unread.map { book in
            let base = book.purchase.purchasedAt ?? book.addedAt
            let start = calendar.startOfDay(for: base)
            let components = calendar.dateComponents([.day], from: start, to: today)
            return max(0, components.day ?? 0)
        }
        let average = daysList.isEmpty ? 0 : Int((Double(daysList.reduce(0, +)) / Double(daysList.count)).rounded())

        // 「今月増えた」は Notion 03 の記述に従い status でフィルタせず addedAt が当月のものを数える。
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let addedThisMonth = books.filter { book in
            book.addedAt >= monthStart
        }.count

        return Snapshot(count: count, averageDays: average, addedThisMonth: addedThisMonth)
    }
}
