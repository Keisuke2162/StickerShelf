#if canImport(UIKit)
import Foundation
import Observation
import Domain
import Application

@MainActor
@Observable
public final class PileViewModel {
    public enum Display: Hashable { case pile, list }

    public private(set) var boards: [Board] = []
    /// nil のとき「すべての積読」。
    public private(set) var selectedBoardID: BoardID?
    public private(set) var books: [Book] = []
    public private(set) var statistics: TsundokuStatistics.Snapshot = .init(count: 0, averageDays: 0, addedThisMonth: 0)
    public private(set) var isLoading = false
    public var display: Display = .pile
    public var errorMessage: String?

    private let container: PresentationContainer
    private let calendar: Calendar

    public init(container: PresentationContainer, calendar: Calendar = .current) {
        self.container = container
        self.calendar = calendar
    }

    public func start() async {
        async let a: Void = observeBookChanges()
        async let b: Void = observeBoardChanges()
        _ = await (a, b)
    }

    private func observeBookChanges() async {
        for await _ in container.bookChanges() {
            await reloadBooks()
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
    }

    private func reloadBoards() async {
        do {
            boards = try await container.fetchBoards.execute(kind: .pile)
            if let id = selectedBoardID, !boards.contains(where: { $0.id == id }) {
                selectedBoardID = nil
                await reloadBooks()
            }
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    private func reloadBooks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let out = try await container.fetchPile.execute(boardID: selectedBoardID, now: Date())
            books = out.books
            statistics = out.statistics
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func select(boardID: BoardID?) {
        selectedBoardID = boardID
        Task { await reloadBooks() }
    }

    public func createBoard(name: String) async {
        do {
            let board = try await container.createBoard.execute(name: name, kind: .pile, now: Date())
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

    public func daysInPile(for book: Book) -> Int {
        let today = calendar.startOfDay(for: Date())
        let base = calendar.startOfDay(for: book.purchase.purchasedAt ?? book.addedAt)
        return max(0, calendar.dateComponents([.day], from: base, to: today).day ?? 0)
    }

    public func startReading(id: BookID) async {
        do { _ = try await container.changeStatus.execute(id: id, newStatus: .reading, now: Date()) } catch { errorMessage = DomainErrorMessage.describe(error) }
    }

    public func markFinished(id: BookID) async {
        do { _ = try await container.changeStatus.execute(id: id, newStatus: .finished, now: Date()) } catch { errorMessage = DomainErrorMessage.describe(error) }
    }

    public func moveToBoard(id: BookID, boardID: BoardID?) async {
        do { try await container.moveBookToBoard.execute(bookID: id, boardID: boardID) } catch { errorMessage = DomainErrorMessage.describe(error) }
    }

    public func deleteBook(id: BookID) async {
        do { try await container.deleteBook.execute(id: id) } catch { errorMessage = DomainErrorMessage.describe(error) }
    }
}

#endif
