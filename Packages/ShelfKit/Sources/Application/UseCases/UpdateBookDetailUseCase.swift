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
        // 3. ボード割当。本棚ステータスへの遷移時は shelf 側に整合させる。unread は draft をそのまま尊重。
        if let shelfResolver, draft.status != .unread {
            let resolved = await shelfResolver.resolve(status: draft.status, desiredBoardID: draft.boardID)
            book.moveToBoard(resolved)
        } else {
            book.moveToBoard(draft.boardID)
        }
        try await books.save(book)
        return book
    }
}
