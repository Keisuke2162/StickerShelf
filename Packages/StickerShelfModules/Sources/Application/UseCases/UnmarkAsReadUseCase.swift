import Foundation
import Domain

public protocol UnmarkAsReadUseCaseProtocol: Sendable {
    func execute(id: BookID, date: Date) async throws -> Book
}

public struct UnmarkAsReadUseCase: UnmarkAsReadUseCaseProtocol {
    private let books: BookRepository
    private let calendar: Calendar

    public init(books: BookRepository, calendar: Calendar = .current) {
        self.books = books
        self.calendar = calendar
    }

    public func execute(id: BookID, date: Date) async throws -> Book {
        guard var book = try await books.fetch(id: id) else {
            throw DomainError.bookNotFound(id)
        }
        book.unmarkAsRead(on: date, calendar: calendar)
        try await books.save(book)
        return book
    }
}
