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
                // 初期 boardID はブック本体の値を優先。無ければ status に対応する kind の先頭 Board。
                let fallbackKind: BoardKind = book.status == .unread ? .pile : .shelf
                let fallback = boards.first { $0.kind == fallbackKind }?.id
                draft = BookDetailDraft(
                    status: book.status,
                    finishedAt: book.period.finishedAt,
                    purchasedAt: book.purchase.purchasedAt,
                    stickerEdge: book.stickerEdge,
                    boardID: book.boardID ?? fallback
                )
            }
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func boards(for status: ReadingStatus) -> [Board] {
        let kind: BoardKind = status == .unread ? .pile : .shelf
        return boards.filter { $0.kind == kind }
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

    public func markAsRead(on date: Date) async {
        do {
            book = try await container.markAsRead.execute(id: bookID, date: date)
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    public func unmarkAsRead(on date: Date) async {
        do {
            book = try await container.unmarkAsRead.execute(id: bookID, date: date)
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
        }
    }

    /// 読んだ日ログを降順で返す（新しい日付が上）。
    public var sortedReadDays: [Date] {
        (book?.readDays ?? []).sorted(by: >)
    }
}

#endif
