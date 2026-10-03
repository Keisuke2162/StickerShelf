import Foundation
import Domain

public protocol ChangeReadingStatusUseCaseProtocol: Sendable {
    func execute(id: BookID, newStatus: ReadingStatus, now: Date) async throws -> Book
}

public struct ChangeReadingStatusUseCase: ChangeReadingStatusUseCaseProtocol {
    private let books: BookRepository
    private let placementFactory: StickerPlacementFactory
    private let shelfResolver: ShelfBoardResolver?

    public init(
        books: BookRepository,
        placementFactory: StickerPlacementFactory = .init(),
        shelfResolver: ShelfBoardResolver? = nil
    ) {
        self.books = books
        self.placementFactory = placementFactory
        self.shelfResolver = shelfResolver
    }

    public func execute(id: BookID, newStatus: ReadingStatus, now: Date) async throws -> Book {
        guard var book = try await books.fetch(id: id) else {
            throw DomainError.bookNotFound(id)
        }
        let existingZ = try await books.fetch(status: [.reading, .finished])
            .compactMap(\.sticker)
            .map(\.zIndex)
        try book.changeStatus(to: newStatus, on: now) {
            placementFactory.make(existingZIndexes: existingZ)
        }
        // 本棚ステータスへの遷移では boardID を shelf 側に整合させる。
        if let shelfResolver, newStatus != .unread {
            let resolved = await shelfResolver.resolve(status: newStatus, desiredBoardID: book.boardID)
            book.moveToBoard(resolved)
        }
        try await books.save(book)
        return book
    }
}
