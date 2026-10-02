import Foundation
import Domain

public struct FetchShelfOutput: Sendable {
    public let books: [Book]
    public init(books: [Book]) {
        self.books = books
    }
}

public protocol FetchShelfUseCaseProtocol: Sendable {
    func execute(boardID: BoardID) async throws -> FetchShelfOutput
}

public struct FetchShelfUseCase: FetchShelfUseCaseProtocol {
    private let books: BookRepository

    public init(books: BookRepository) {
        self.books = books
    }

    public func execute(boardID: BoardID) async throws -> FetchShelfOutput {
        let onBoard = try await books.fetch(boardID: boardID)
        // zIndex 昇順。sticker を持たない本は末尾へ。
        let sorted = onBoard.sorted { lhs, rhs in
            (lhs.sticker?.zIndex ?? Int.min) < (rhs.sticker?.zIndex ?? Int.min)
        }
        return FetchShelfOutput(books: sorted)
    }
}
