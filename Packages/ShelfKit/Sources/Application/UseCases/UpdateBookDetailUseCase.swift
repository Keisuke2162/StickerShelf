import Foundation
import Domain

public struct BookDetailDraft: Sendable {
    public var status: ReadingStatus
    public var finishedAt: Date?
    public var purchasedAt: Date?
    public var stickerEdge: StickerEdge
    public var boardID: BoardID?

    public init(status: ReadingStatus, finishedAt: Date?, purchasedAt: Date?, stickerEdge: StickerEdge, boardID: BoardID?) {
        self.status = status
        self.finishedAt = finishedAt
        self.purchasedAt = purchasedAt
        self.stickerEdge = stickerEdge
        self.boardID = boardID
    }
}

public protocol UpdateBookDetailUseCaseProtocol: Sendable {
    func execute(id: BookID, draft: BookDetailDraft, now: Date) async throws -> Book
}

public struct UpdateBookDetailUseCase: UpdateBookDetailUseCaseProtocol {
    private let books: BookRepository
    private let placementFactory: StickerPlacementFactory

    public init(books: BookRepository, placementFactory: StickerPlacementFactory = .init()) {
        self.books = books
        self.placementFactory = placementFactory
    }

    public func execute(id: BookID, draft: BookDetailDraft, now: Date) async throws -> Book {
        guard var book = try await books.fetch(id: id) else {
            throw DomainError.bookNotFound(id)
        }
        // 1. まずステータス遷移を適用（Book のドメインルールで補完）
        if book.status != draft.status {
            let existingZ = try await books.fetch(status: [.reading, .finished])
                .compactMap(\.sticker)
                .map(\.zIndex)
            try book.changeStatus(to: draft.status, on: now) {
                placementFactory.make(existingZIndexes: existingZ)
            }
        }
        // 2. 次に draft の明示値で日付を上書き（startedAt は Book の自動補完に委ねる）
        try book.updatePeriod(startedAt: book.period.startedAt, finishedAt: draft.finishedAt)
        book.updatePurchase(PurchaseInfo(purchasedAt: draft.purchasedAt, place: book.purchase.place))
        book.changeStickerEdge(draft.stickerEdge)
        // 3. ボード割当。unread のときは nil 強制。
        book.moveToBoard(draft.status == .unread ? nil : draft.boardID)
        try await books.save(book)
        return book
    }
}
