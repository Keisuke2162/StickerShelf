#if canImport(UIKit)
import Foundation
import Observation
import Domain
import Application

@MainActor
@Observable
public final class ShelfViewModel {
    public private(set) var boards: [Board] = []
    public private(set) var selectedBoardID: BoardID?
    public private(set) var books: [Book] = []
    public private(set) var pileCount: Int = 0
    public private(set) var isLoading = false
    public var errorMessage: String?
    public var popAnimationIDs: Set<BookID> = []

    private let container: PresentationContainer

    public init(container: PresentationContainer) {
        self.container = container
    }

    public func start() async {
        async let a: Void = observeBookChanges()
        async let b: Void = observeBoardChanges()
        _ = await (a, b)
    }

    private func observeBookChanges() async {
        for await _ in container.bookChanges() {
            await reloadBooks()
            await reloadPileCount()
        }
    }

    private func observeBoardChanges() async {
        for await _ in container.boardChanges() {
            await reloadBoards()
        }
    }

    public func reload() async {
        await reloadBoards()
        await reloadBooks()
        await reloadPileCount()
    }

    private func reloadBoards() async {
        do {
            boards = try await container.fetchBoards.execute()
            if selectedBoardID == nil || !boards.contains(where: { $0.id == selectedBoardID }) {
                selectedBoardID = boards.first?.id
                await reloadBooks()
            }
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    private func reloadBooks() async {
        isLoading = true
        defer { isLoading = false }
        guard let boardID = selectedBoardID else {
            books = []
            return
        }
        do {
            let out = try await container.fetchShelf.execute(boardID: boardID)
            let newIDs = Set(out.books.map(\.id)).subtracting(Set(books.map(\.id)))
            books = out.books
            for id in newIDs { popAnimationIDs.insert(id) }
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    private func reloadPileCount() async {
        do {
            pileCount = try await container.fetchPile.execute(now: Date()).books.count
        } catch { }
    }

    public func select(boardID: BoardID) {
        selectedBoardID = boardID
        Task { await reloadBooks() }
    }

    public func createBoard(name: String) async {
        do {
            let board = try await container.createBoard.execute(name: name, now: Date())
            await reloadBoards()
            select(boardID: board.id)
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func deleteCurrentBoard() async {
        guard let id = selectedBoardID else { return }
        do {
            try await container.deleteBoard.execute(id: id)
            selectedBoardID = nil
            await reload()
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func didTouchSticker(id: BookID) async {
        do { try await container.bringToFront.execute(id: id) } catch { errorMessage = DomainErrorMessage.describe(error) }
    }

    public func didEndGesture(id: BookID, placement: StickerPlacement) async {
        do { try await container.moveSticker.execute(id: id, placement: placement) } catch { errorMessage = DomainErrorMessage.describe(error) }
    }

    public func returnToPile(id: BookID) async {
        do { _ = try await container.changeStatus.execute(id: id, newStatus: .unread, now: Date()) } catch { errorMessage = DomainErrorMessage.describe(error) }
    }

    public func deleteBook(id: BookID) async {
        do { try await container.deleteBook.execute(id: id) } catch { errorMessage = DomainErrorMessage.describe(error) }
    }

    public func clearPopAnimation(id: BookID) {
        popAnimationIDs.remove(id)
    }
}

#endif
