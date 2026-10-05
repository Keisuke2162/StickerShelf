#if canImport(UIKit)
import Foundation
import Observation
import Domain
import Application

@MainActor
@Observable
public final class AddBookViewModel {
    public enum Destination: Hashable {
        case shelf, pile
    }

    public var keyword: String = ""
    public var destination: Destination = .pile
    public var purchasedAt: Date = Date()
    public var selectedShelfBoardID: BoardID?
    public var selectedPileBoardID: BoardID?
    public private(set) var shelfBoards: [Board] = []
    public private(set) var pileBoards: [Board] = []
    public private(set) var results: [SearchCatalogOutput.Item] = []
    public private(set) var isSearching = false
    public private(set) var isAdding = false
    public var selectedCatalog: CatalogBook?
    public var errorMessage: String?
    public var addedBook: Book?

    private let container: PresentationContainer
    private var searchTask: Task<Void, Never>?

    public init(container: PresentationContainer, initialKeyword: String = "") {
        self.container = container
        self.keyword = initialKeyword
    }

    public var boardsForCurrentDestination: [Board] {
        destination == .shelf ? shelfBoards : pileBoards
    }

    public var selectedBoardIDForCurrentDestination: BoardID? {
        get { destination == .shelf ? selectedShelfBoardID : selectedPileBoardID }
        set {
            if destination == .shelf { selectedShelfBoardID = newValue }
            else { selectedPileBoardID = newValue }
        }
    }

    public func loadBoards() async {
        shelfBoards = (try? await container.fetchBoards.execute(kind: .shelf)) ?? []
        pileBoards = (try? await container.fetchBoards.execute(kind: .pile)) ?? []
        if selectedShelfBoardID == nil { selectedShelfBoardID = shelfBoards.first?.id }
        // 積読は「未分類」(nil) をデフォルトとする
    }

    public func createBoard(name: String) async {
        do {
            let kind: BoardKind = destination == .shelf ? .shelf : .pile
            let board = try await container.createBoard.execute(name: name, kind: kind, now: Date())
            await loadBoards()
            if kind == .shelf {
                selectedShelfBoardID = board.id
            } else {
                selectedPileBoardID = board.id
            }
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func onKeywordChanged() {
        searchTask?.cancel()
        let keyword = self.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            results = []
            selectedCatalog = nil
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            await self?.search(keyword: keyword)
        }
    }

    public func search(keyword: String) async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let out = try await container.searchCatalog.execute(keyword: keyword, page: 0)
            results = out.items
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
            results = []
        }
    }

    public func lookupISBN(_ isbn: ISBN) async {
        isSearching = true
        defer { isSearching = false }
        await search(keyword: isbn.value)
        if let first = results.first, !first.alreadyRegistered {
            selectedCatalog = first.catalog
        }
    }

    private func initialStatus() -> ReadingStatus {
        destination == .pile ? .unread : .reading
    }

    private func effectiveBoardID() -> BoardID? {
        destination == .shelf ? selectedShelfBoardID : selectedPileBoardID
    }

    public func addSelected() async -> Book? {
        guard let selectedCatalog else { return nil }
        if destination == .shelf, effectiveBoardID() == nil {
            errorMessage = "本棚を選ぶか、先に本棚を作成してください。"
            return nil
        }
        isAdding = true
        defer { isAdding = false }
        do {
            let input = AddBookInput(source: .catalog(selectedCatalog), initialStatus: initialStatus(), boardID: effectiveBoardID(), purchasedAt: purchasedAt, now: Date())
            let book = try await container.addBook.execute(input)
            addedBook = book
            return book
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
            return nil
        }
    }

    public func addManual(entry: AddBookInput.ManualEntry, coverImageData: Data? = nil) async -> Book? {
        if destination == .shelf, effectiveBoardID() == nil {
            errorMessage = "本棚を選ぶか、先に本棚を作成してください。"
            return nil
        }
        isAdding = true
        defer { isAdding = false }
        do {
            // カメラ撮影済みの画像がある場合はローカル保存して CoverImage.local を entry に差し込む。
            let finalEntry: AddBookInput.ManualEntry
            if let coverImageData {
                let cover = try await container.coverImages.saveUserImage(coverImageData)
                finalEntry = AddBookInput.ManualEntry(
                    title: entry.title,
                    authors: entry.authors,
                    publisher: entry.publisher,
                    pageCount: entry.pageCount,
                    isbn: entry.isbn,
                    cover: cover
                )
            } else {
                finalEntry = entry
            }
            let input = AddBookInput(source: .manual(finalEntry), initialStatus: initialStatus(), boardID: effectiveBoardID(), purchasedAt: purchasedAt, now: Date())
            let book = try await container.addBook.execute(input)
            addedBook = book
            return book
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
            return nil
        }
    }
}

#endif
