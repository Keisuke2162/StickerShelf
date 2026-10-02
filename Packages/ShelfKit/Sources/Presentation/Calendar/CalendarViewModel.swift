#if canImport(UIKit)
import Foundation
import Observation
import Domain

@MainActor
@Observable
public final class CalendarViewModel {
    public private(set) var summary: ReadingCalendar.MonthSummary?
    public private(set) var isLoading = false
    public var year: Int
    public var month: Int
    public var selectedDay: Date?
    public var errorMessage: String?

    private let container: PresentationContainer
    private let calendar: Calendar

    public init(container: PresentationContainer, calendar: Calendar = .current, now: Date = Date()) {
        self.container = container
        self.calendar = calendar
        let components = calendar.dateComponents([.year, .month], from: now)
        self.year = components.year ?? 2026
        self.month = components.month ?? 1
    }

    public func start() async {
        for await _ in container.bookChanges() { await reload() }
    }

    public func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try await container.fetchCalendar.execute(year: year, month: month)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func moveMonth(by delta: Int) async {
        var components = DateComponents(year: year, month: month, day: 1)
        guard let date = calendar.date(from: components),
              let next = calendar.date(byAdding: .month, value: delta, to: date) else { return }
        components = calendar.dateComponents([.year, .month], from: next)
        year = components.year ?? year
        month = components.month ?? month
        selectedDay = nil
        await reload()
    }

    public func daysGrid() -> [Date?] {
        var components = DateComponents(year: year, month: month, day: 1)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = ((weekday - calendar.firstWeekday) + 7) % 7
        let range = calendar.range(of: .day, in: .month, for: firstOfMonth) ?? 1..<2
        var out: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            components.day = day
            if let date = calendar.date(from: components) {
                out.append(date)
            }
        }
        while out.count % 7 != 0 { out.append(nil) }
        return out
    }

    public func books(for day: Date) -> [Book] {
        guard let summary else { return [] }
        return summary.booksByDay[calendar.startOfDay(for: day)] ?? []
    }
}

#endif
