#if canImport(UIKit)
import Foundation
import Observation
import Domain
import Application

@MainActor
@Observable
public final class ShelfViewModel {
    public enum Filter: Hashable, CaseIterable {
        case all, readingOnly, finishedOnly
        var mapped: ShelfFilter {
            switch self {
            case .all: return .all
            case .readingOnly: return .readingOnly
            case .finishedOnly: return .finishedOnly
            }
        }
    }

    public private(set) var books: [Book] = []
    public private(set) var countReading = 0
    public private(set) var countFinished = 0
    public private(set) var countUnread = 0
    public private(set) var isLoading = false
    public var filter: Filter = .all {
        didSet { Task { await reload() } }
    }
    public var errorMessage: String?
    public var pendingPlacement: [BookID: StickerPlacement] = [:]
    public var popAnimationIDs: Set<BookID> = []

    private let container: PresentationContainer

    public init(container: PresentationContainer) {
        self.container = container
    }

    public func start() async {
        for await _ in container.bookChanges() {
            await reload()
        }
    }

    public func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let shelf = try await container.fetchShelf.execute(filter: filter.mapped)
            let pile = try await container.fetchPile.execute(now: Date())
            let newIDs = Set(shelf.books.map(\.id)).subtracting(Set(books.map(\.id)))
            books = shelf.books
            countReading = shelf.counts.reading
            countFinished = shelf.counts.finished
            countUnread = pile.books.count
            for id in newIDs { popAnimationIDs.insert(id) }
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func didTouchSticker(id: BookID) async {
        do { try await container.bringToFront.execute(id: id) } catch { errorMessage = DomainErrorMessage.describe(error) }
    }

    public func didEndGesture(id: BookID, placement: StickerPlacement) async {
        pendingPlacement.removeValue(forKey: id)
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
