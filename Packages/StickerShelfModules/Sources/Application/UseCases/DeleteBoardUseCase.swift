import Foundation
import Domain

public protocol DeleteBoardUseCaseProtocol: Sendable {
    func execute(id: BoardID) async throws
}

public struct DeleteBoardUseCase: DeleteBoardUseCaseProtocol {
    private let boards: BoardRepository
    private let books: BookRepository

    public init(boards: BoardRepository, books: BookRepository) {
        self.boards = boards
        self.books = books
    }

    public func execute(id: BoardID) async throws {
        // ボードに属する本は boardID を外す（本自体は削除しない。「読んだ」扱いになる想定）
        var affected = try await books.fetch(boardID: id)
        for i in affected.indices { affected[i].moveToBoard(nil) }
        try await books.saveAll(affected)
        try await boards.delete(id: id)
    }
}
