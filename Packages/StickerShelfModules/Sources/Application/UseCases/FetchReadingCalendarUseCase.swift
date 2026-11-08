import Foundation
import Domain

public protocol FetchReadingCalendarUseCaseProtocol: Sendable {
    func execute(year: Int, month: Int) async throws -> ReadingCalendar.MonthSummary
}

public struct FetchReadingCalendarUseCase: FetchReadingCalendarUseCaseProtocol {
    private let books: BookRepository
    private let calendar: ReadingCalendar

    public init(books: BookRepository, calendar: ReadingCalendar = .init()) {
        self.books = books
        self.calendar = calendar
    }

    public func execute(year: Int, month: Int) async throws -> ReadingCalendar.MonthSummary {
        let books = try await self.books.fetchAll()
        return calendar.summary(books: books, year: year, month: month)
    }
}
