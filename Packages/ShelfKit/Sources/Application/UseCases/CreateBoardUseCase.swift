import Foundation
import Domain

public protocol CreateBoardUseCaseProtocol: Sendable {
    func execute(name: String, now: Date) async throws -> Board
}

public struct CreateBoardUseCase: CreateBoardUseCaseProtocol {
    private let boards: BoardRepository

    public init(boards: BoardRepository) {
        self.boards = boards
    }

    public func execute(name: String, now: Date) async throws -> Board {
        let existing = try await boards.fetchAll()
        let nextOrder = (existing.map(\.sortOrder).max() ?? 0) + 1
        let board = try Board(name: name, createdAt: now, sortOrder: nextOrder)
        try await boards.save(board)
        return board
    }
}
