#if canImport(UIKit)
import Foundation
import Observation
import Domain
import Application

@MainActor
@Observable
public final class BookDetailViewModel {
    public private(set) var book: Book?
    public private(set) var boards: [Board] = []
    public private(set) var isSaving = false
    public var errorMessage: String?

    public var draft: BookDetailDraft?

    private let container: PresentationContainer
    public let bookID: BookID

    public init(container: PresentationContainer, bookID: BookID) {
        self.container = container
        self.bookID = bookID
    }

    public func load() async {
        boards = (try? await container.fetchBoards.execute()) ?? []
        do {
            book = try await container.fetchBookDetail.execute(id: bookID)
            if let book {
                draft = BookDetailDraft(
                    status: book.status,
                    finishedAt: book.period.finishedAt,
                    purchasedAt: book.purchase.purchasedAt,
                    stickerEdge: book.stickerEdge,
                    boardID: book.boardID ?? boards.first?.id
                )
            }
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func save() async -> Bool {
        guard let draft else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            book = try await container.updateBookDetail.execute(id: bookID, draft: draft, now: Date())
            return true
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
            return false
        }
    }

    public func delete() async -> Bool {
        do {
            try await container.deleteBook.execute(id: bookID)
            return true
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
            return false
        }
    }

    public func replaceCover(data: Data) async {
        do {
            book = try await container.replaceCover.execute(id: bookID, imageData: data)
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }
}

#endif
