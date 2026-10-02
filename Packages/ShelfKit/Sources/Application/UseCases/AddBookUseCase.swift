import Foundation
import Domain

public struct AddBookInput: Sendable {
    public let source: Source
    public let initialStatus: ReadingStatus
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

    public init(source: Source, initialStatus: ReadingStatus, purchasedAt: Date?, now: Date) {
        self.source = source
        self.initialStatus = initialStatus
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

        let existingZIndexes = try await books.fetch(status: [.reading, .finished])
            .compactMap(\.sticker)
            .map(\.zIndex)
        let sticker: StickerPlacement? = input.initialStatus == .unread
            ? nil
            : placementFactory.make(existingZIndexes: existingZIndexes)

        var book = try Book(
            metadata: metadata,
            status: input.initialStatus,
            period: initialPeriod(status: input.initialStatus, now: input.now),
            purchase: PurchaseInfo(purchasedAt: input.purchasedAt),
            sticker: sticker,
            cover: cover,
            addedAt: input.now
        )
        // 進捗の初期値（finished の場合は満ページ）を Book のドメインルールで整える。
        if input.initialStatus == .finished, let total = metadata.pageCount {
            try book.updateProgress(currentPage: total)
        }
        try await books.save(book)
        return book
    }

    private func initialPeriod(status: ReadingStatus, now: Date) -> ReadingPeriod {
        switch status {
        case .unread:
            return .init()
        case .reading:
            return ReadingPeriod(startedAt: now, finishedAt: nil)
        case .finished:
            return ReadingPeriod(startedAt: now, finishedAt: now)
        }
    }
}
