import Foundation
import Domain

public protocol DeleteBookUseCaseProtocol: Sendable {
    func execute(id: BookID) async throws
}

public struct DeleteBookUseCase: DeleteBookUseCaseProtocol {
    private let books: BookRepository
    private let covers: CoverImageRepository

    public init(books: BookRepository, covers: CoverImageRepository) {
        self.books = books
        self.covers = covers
    }

    public func execute(id: BookID) async throws {
        if let book = try await books.fetch(id: id), book.cover.isLocal {
            try await covers.deleteLocal(book.cover)
        }
        try await books.delete(id: id)
    }
}
