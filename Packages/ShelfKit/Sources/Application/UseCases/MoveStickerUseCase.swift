import Foundation
import Domain

public protocol MoveStickerUseCaseProtocol: Sendable {
    func execute(id: BookID, placement: StickerPlacement) async throws
}

public struct MoveStickerUseCase: MoveStickerUseCaseProtocol {
    private let books: BookRepository

    public init(books: BookRepository) {
        self.books = books
    }

    public func execute(id: BookID, placement: StickerPlacement) async throws {
        guard var book = try await books.fetch(id: id) else {
            throw DomainError.catalogUnavailable(reason: "book not found")
        }
        try book.moveSticker(to: placement)
        try await books.save(book)
    }
}
