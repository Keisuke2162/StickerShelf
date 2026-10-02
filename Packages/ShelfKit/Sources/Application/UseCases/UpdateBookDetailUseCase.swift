import Foundation
import Domain

public struct BookDetailDraft: Sendable {
    public var status: ReadingStatus
    public var currentPage: Int
    public var startedAt: Date?
    public var finishedAt: Date?
    public var purchasedAt: Date?
    public var purchasePlace: String
    public var memo: String
    public var stickerEdge: StickerEdge

    public init(status: ReadingStatus, currentPage: Int, startedAt: Date?, finishedAt: Date?, purchasedAt: Date?, purchasePlace: String, memo: String, stickerEdge: StickerEdge) {
        self.status = status
        self.currentPage = currentPage
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.purchasedAt = purchasedAt
        self.purchasePlace = purchasePlace
        self.memo = memo
        self.stickerEdge = stickerEdge
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
            throw DomainError.catalogUnavailable(reason: "book not found")
        }
        // 期間と進捗はドメインの検証を通す。
        try book.updatePeriod(startedAt: draft.startedAt, finishedAt: draft.finishedAt)
        try book.updateProgress(currentPage: draft.currentPage)
        book.updatePurchase(PurchaseInfo(purchasedAt: draft.purchasedAt, place: draft.purchasePlace))
        book.updateMemo(draft.memo)
        book.changeStickerEdge(draft.stickerEdge)

        if book.status != draft.status {
            let existingZ = try await books.fetch(status: [.reading, .finished])
                .compactMap(\.sticker)
                .map(\.zIndex)
            try book.changeStatus(to: draft.status, on: now) {
                placementFactory.make(existingZIndexes: existingZ)
            }
        }

        try await books.save(book)
        return book
    }
}
