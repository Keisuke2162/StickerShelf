import Foundation
import Domain

public protocol ChangeReadingStatusUseCaseProtocol: Sendable {
    func execute(id: BookID, newStatus: ReadingStatus, now: Date) async throws -> Book
}

public struct ChangeReadingStatusUseCase: ChangeReadingStatusUseCaseProtocol {
    private let books: BookRepository
    private let placementFactory: StickerPlacementFactory

    public init(books: BookRepository, placementFactory: StickerPlacementFactory = .init()) {
        self.books = books
        self.placementFactory = placementFactory
    }

    public func execute(id: BookID, newStatus: ReadingStatus, now: Date) async throws -> Book {
        guard var book = try await books.fetch(id: id) else {
            throw DomainError.catalogUnavailable(reason: "book not found")
        }
        let existingZ = try await books.fetch(status: [.reading, .finished])
            .compactMap(\.sticker)
            .map(\.zIndex)
        try book.changeStatus(to: newStatus, on: now) {
            placementFactory.make(existingZIndexes: existingZ)
        }
        try await books.save(book)
        return book
    }
}
