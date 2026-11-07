import Foundation
import Domain

public struct AddBookInput: Sendable {
    public let source: Source
    public let initialStatus: ReadingStatus
    /// 所属フォルダ。本棚ステータス（.reading/.finished）では本棚側 Board、
    /// 積読（.unread）では積読側フォルダに所属させる。nil のときは「未分類」。
    public let boardID: BoardID?
    public let purchasedAt: Date?
    public let now: Date

    public enum Source: Sendable {
        case catalog(CatalogBook)
        case manual(ManualEntry)
    }

    public struct ManualEntry: Sendable {
        public let title: String
        public let authors: [String]
        public let publisher: String?
        public let pageCount: Int?
        public let isbn: ISBN?
        public let cover: CoverImage

        public init(title: String, authors: [String] = [], publisher: String? = nil, pageCount: Int? = nil, isbn: ISBN? = nil, cover: CoverImage = .none) {
            self.title = title
            self.authors = authors
            self.publisher = publisher
            self.pageCount = pageCount
            self.isbn = isbn
            self.cover = cover
        }
    }

    public init(source: Source, initialStatus: ReadingStatus, boardID: BoardID? = nil, purchasedAt: Date?, now: Date) {
        self.source = source
        self.initialStatus = initialStatus
        self.boardID = boardID
        self.purchasedAt = purchasedAt
        self.now = now
    }
}

public protocol AddBookUseCaseProtocol: Sendable {
    func execute(_ input: AddBookInput) async throws -> Book
}

public struct AddBookUseCase: AddBookUseCaseProtocol {
    private let books: BookRepository
    private let placementFactory: StickerPlacementFactory

    public init(books: BookRepository, placementFactory: StickerPlacementFactory = .init()) {
        self.books = books
        self.placementFactory = placementFactory
    }

    public func execute(_ input: AddBookInput) async throws -> Book {
        let metadata: BookMetadata
        let cover: CoverImage
        switch input.source {
        case .catalog(let catalog):
            metadata = catalog.metadata
            cover = catalog.metadata.remoteCoverURL.map(CoverImage.remote) ?? .none
        case .manual(let entry):
            metadata = try BookMetadata(
                title: entry.title,
                authors: entry.authors,
                publisher: entry.publisher,
                pageCount: entry.pageCount,
                isbn: entry.isbn
            )
            cover = entry.cover
        }

        if let isbn = metadata.isbn, let existing = try await books.fetch(isbn: isbn) {
            throw DomainError.duplicateBook(existing.id)
        }

        // いったん unread で作ってから、必要なら changeStatus でドメインルールを通す。
        var book = try Book(
            metadata: metadata,
            status: .unread,
            purchase: PurchaseInfo(purchasedAt: input.purchasedAt),
            cover: cover,
            addedAt: input.now
        )
        if input.initialStatus != .unread {
            let existingZ = try await books.fetch(status: [.reading, .finished])
                .compactMap(\.sticker)
                .map(\.zIndex)
            try book.changeStatus(to: input.initialStatus, on: input.now) {
                placementFactory.make(existingZIndexes: existingZ)
            }
        }
        // 本棚でも積読でも、選択されたフォルダに所属させる。
        book.moveToBoard(input.boardID)
        try await books.save(book)
        return book
    }
}
