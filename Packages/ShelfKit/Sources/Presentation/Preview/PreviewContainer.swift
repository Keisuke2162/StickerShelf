#if canImport(UIKit) && DEBUG
import Foundation
import SwiftUI
import Domain
import Application

/// Preview・SwiftUI Preview 用の軽量 `PresentationContainer` ビルダー。
/// SwiftData・Keychain・URLSession なしで全画面を描画できる。
public enum PreviewSupport {
    @MainActor
    public static func makeContainer() -> PresentationContainer {
        let readingBoard = (try? Board(kind: .shelf, name: "読んでる", createdAt: Date(), sortOrder: 1))!
        let finishedBoard = (try? Board(kind: .shelf, name: "読んだ", createdAt: Date(), sortOrder: 2))!
        let laterBoard = (try? Board(kind: .pile, name: "あとで読む", createdAt: Date(), sortOrder: 3))!
        let mangaBoard = (try? Board(kind: .pile, name: "漫画", createdAt: Date(), sortOrder: 4))!
        let repository = PreviewBookRepository(initial: sampleBooks(readingBoardID: readingBoard.id, finishedBoardID: finishedBoard.id, pileBoardIDs: [laterBoard.id, mangaBoard.id]))
        let boardRepo = PreviewBoardRepository(initial: [readingBoard, finishedBoard, laterBoard, mangaBoard])
        let catalog = PreviewCatalogRepository()
        let apiKeys = PreviewAPIKeyRepository()
        let covers = PreviewCoverImageRepository()
        let prefs = PreviewSearchPreferences()
        return PresentationContainer(
            searchCatalog: SearchCatalogUseCase(catalog: catalog, books: repository),
            findCatalogByISBN: FindCatalogBookByISBNUseCase(catalog: catalog),
            addBook: AddBookUseCase(books: repository),
            fetchShelf: FetchShelfUseCase(books: repository),
            fetchPile: FetchPileUseCase(books: repository),
            fetchCalendar: FetchReadingCalendarUseCase(books: repository),
            fetchBookDetail: FetchBookDetailUseCase(books: repository),
            updateBookDetail: UpdateBookDetailUseCase(books: repository),
            changeStatus: ChangeReadingStatusUseCase(books: repository),
            moveSticker: MoveStickerUseCase(books: repository),
            bringToFront: BringStickerToFrontUseCase(books: repository),
            replaceCover: ReplaceCoverImageUseCase(books: repository, covers: covers),
            deleteBook: DeleteBookUseCase(books: repository, covers: covers),
            saveAPIKey: SaveAPIKeyUseCase(repository: apiKeys),
            deleteAPIKey: DeleteAPIKeyUseCase(repository: apiKeys),
            loadAPIKeyStatus: LoadAPIKeyStatusUseCase(repository: apiKeys),
            testConnection: TestCatalogConnectionUseCase(catalog: catalog),
            fetchBoards: FetchBoardsUseCase(boards: boardRepo),
            createBoard: CreateBoardUseCase(boards: boardRepo),
            deleteBoard: DeleteBoardUseCase(boards: boardRepo, books: repository),
            moveBookToBoard: MoveBookToBoardUseCase(books: repository),
            searchPreferences: prefs,
            coverImages: covers,
            bookChanges: { repository.changes() },
            boardChanges: { boardRepo.changes() }
        )
    }

    public static func sampleBooks(readingBoardID: BoardID, finishedBoardID: BoardID, pileBoardIDs: [BoardID] = []) -> [Book] {
        let factory = StickerPlacementFactory()
        let now = Date()
        var zIndexes: [Int] = []
        var books: [Book] = []
        for i in 0..<6 {
            guard let meta = try? BookMetadata(title: "サンプル書籍 \(i + 1)", authors: ["著者 \(i + 1)"], pageCount: 240) else { continue }
            let placement = factory.make(existingZIndexes: zIndexes)
            zIndexes.append(placement.zIndex)
            let isReading = i.isMultiple(of: 2)
            if let book = try? Book(
                metadata: meta,
                status: isReading ? .reading : .finished,
                period: isReading ? ReadingPeriod(startedAt: now) : ReadingPeriod(startedAt: now, finishedAt: now),
                progress: ReadingProgress(currentPage: 120),
                sticker: placement,
                boardID: isReading ? readingBoardID : finishedBoardID,
                addedAt: now.addingTimeInterval(-Double(i) * 86400)
            ) {
                books.append(book)
            }
        }
        for i in 0..<4 {
            guard let meta = try? BookMetadata(title: "積読サンプル \(i + 1)", pageCount: 200) else { continue }
            let pileBoardID: BoardID? = pileBoardIDs.isEmpty ? nil : pileBoardIDs[i % pileBoardIDs.count]
            if let book = try? Book(
                metadata: meta,
                status: .unread,
                purchase: PurchaseInfo(purchasedAt: now.addingTimeInterval(-Double(i) * 86400)),
                boardID: pileBoardID,
                addedAt: now.addingTimeInterval(-Double(i) * 86400)
            ) {
                books.append(book)
            }
        }
        return books
    }
}

actor PreviewBookRepository: BookRepository {
    private var storage: [BookID: Book] = [:]
    nonisolated(unsafe) private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    nonisolated private let continuationsLock = NSLock()

    init(initial: [Book]) { for b in initial { storage[b.id] = b } }

    func fetchAll() async throws -> [Book] { storage.values.sorted { $0.addedAt < $1.addedAt } }
    func fetch(id: BookID) async throws -> Book? { storage[id] }
    func fetch(isbn: ISBN) async throws -> Book? { storage.values.first { $0.metadata.isbn == isbn } }
    func fetch(status: Set<ReadingStatus>) async throws -> [Book] { storage.values.filter { status.contains($0.status) } }
    func fetch(boardID: BoardID) async throws -> [Book] { storage.values.filter { $0.boardID == boardID }.sorted { $0.addedAt < $1.addedAt } }
    func fetchFinished(in interval: DateInterval) async throws -> [Book] {
        storage.values.filter { b in
            guard b.status == .finished, let d = b.period.finishedAt else { return false }
            return d >= interval.start && d < interval.end
        }
    }
    func save(_ book: Book) async throws { storage[book.id] = book; broadcast() }
    func saveAll(_ books: [Book]) async throws { for b in books { storage[b.id] = b }; broadcast() }
    func delete(id: BookID) async throws { storage.removeValue(forKey: id); broadcast() }

    nonisolated func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let token = UUID()
            self.continuationsLock.lock()
            self.continuations[token] = continuation
            self.continuationsLock.unlock()
            continuation.yield(())
            continuation.onTermination = { [weak self] _ in
                self?.continuationsLock.lock()
                self?.continuations.removeValue(forKey: token)
                self?.continuationsLock.unlock()
            }
        }
    }

    private nonisolated func broadcast() {
        continuationsLock.lock()
        let conts = Array(continuations.values)
        continuationsLock.unlock()
        for c in conts { c.yield(()) }
    }
}

actor PreviewBoardRepository: BoardRepository {
    private var storage: [BoardID: Board] = [:]
    nonisolated(unsafe) private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    nonisolated private let continuationsLock = NSLock()

    init(initial: [Board]) { for b in initial { storage[b.id] = b } }

    func fetchAll() async throws -> [Board] { storage.values.sorted { $0.sortOrder < $1.sortOrder } }
    func fetch(id: BoardID) async throws -> Board? { storage[id] }
    func save(_ board: Board) async throws { storage[board.id] = board; broadcast() }
    func delete(id: BoardID) async throws { storage.removeValue(forKey: id); broadcast() }

    nonisolated func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let token = UUID()
            self.continuationsLock.lock()
            self.continuations[token] = continuation
            self.continuationsLock.unlock()
            continuation.yield(())
            continuation.onTermination = { [weak self] _ in
                self?.continuationsLock.lock()
                self?.continuations.removeValue(forKey: token)
                self?.continuationsLock.unlock()
            }
        }
    }

    private nonisolated func broadcast() {
        continuationsLock.lock()
        let conts = Array(continuations.values)
        continuationsLock.unlock()
        for c in conts { c.yield(()) }
    }
}

struct PreviewCatalogRepository: BookCatalogRepository {
    func search(keyword: String, page: Int) async throws -> CatalogSearchResult {
        let items = (0..<5).compactMap { i -> CatalogBook? in
            guard let meta = try? BookMetadata(title: "検索結果 \(keyword) #\(i)", authors: ["著者"], pageCount: 200, isbn: ISBN("9784101010014")) else { return nil }
            return CatalogBook(metadata: meta)
        }
        return CatalogSearchResult(books: items, totalItems: items.count, page: page)
    }
    func find(isbn: ISBN) async throws -> CatalogBook? {
        guard let meta = try? BookMetadata(title: "ISBN 検索結果", pageCount: 200, isbn: isbn) else { return nil }
        return CatalogBook(metadata: meta)
    }
}

final class PreviewAPIKeyRepository: APIKeyRepository, @unchecked Sendable {
    private var key: APIKey?
    func load() throws -> APIKey? { key }
    func save(_ key: APIKey) throws { self.key = key }
    func delete() throws { key = nil }
}

actor PreviewCoverImageRepository: CoverImageRepository {
    func imageData(for cover: CoverImage) async throws -> Data? { nil }
    func saveUserImage(_ data: Data) async throws -> CoverImage { .local(fileName: "preview.jpg") }
    func deleteLocal(_ cover: CoverImage) async throws {}
}

final class PreviewSearchPreferences: SearchPreferenceRepository, @unchecked Sendable {
    private var value = true
    func restrictToJapanese() -> Bool { value }
    func setRestrictToJapanese(_ newValue: Bool) { value = newValue }
}

#Preview("RootView") {
    RootView(container: PreviewSupport.makeContainer())
}

#endif
