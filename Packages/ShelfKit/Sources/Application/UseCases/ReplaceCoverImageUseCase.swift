import Foundation
import Domain

public protocol ReplaceCoverImageUseCaseProtocol: Sendable {
    func execute(id: BookID, imageData: Data) async throws -> Book
}

public struct ReplaceCoverImageUseCase: ReplaceCoverImageUseCaseProtocol {
    private let books: BookRepository
    private let covers: CoverImageRepository

    public init(books: BookRepository, covers: CoverImageRepository) {
        self.books = books
        self.covers = covers
    }

    public func execute(id: BookID, imageData: Data) async throws -> Book {
        guard var book = try await books.fetch(id: id) else {
            throw DomainError.catalogUnavailable(reason: "book not found")
        }
        let old = book.cover
        let newCover = try await covers.saveUserImage(imageData)
        book.replaceCover(newCover)
        try await books.save(book)
        if old.isLocal {
            try await covers.deleteLocal(old)
        }
        return book
    }
}
