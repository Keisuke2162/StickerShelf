import Foundation
import Domain

public protocol MoveBookToBoardUseCaseProtocol: Sendable {
    func execute(bookID: BookID, boardID: BoardID?) async throws
}

public struct MoveBookToBoardUseCase: MoveBookToBoardUseCaseProtocol {
    private let books: BookRepository

    public init(books: BookRepository) {
        self.books = books
    }

    public func execute(bookID: BookID, boardID: BoardID?) async throws {
        guard var book = try await books.fetch(id: bookID) else {
            throw DomainError.bookNotFound(bookID)
        }
        book.moveToBoard(boardID)
        try await books.save(book)
    }
}
