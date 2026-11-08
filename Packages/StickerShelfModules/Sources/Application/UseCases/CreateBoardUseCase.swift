import Foundation
import Domain

public protocol CreateBoardUseCaseProtocol: Sendable {
    func execute(name: String, kind: BoardKind, now: Date) async throws -> Board
}

public struct CreateBoardUseCase: CreateBoardUseCaseProtocol {
    private let boards: BoardRepository

    public init(boards: BoardRepository) {
        self.boards = boards
    }

    public func execute(name: String, kind: BoardKind = .shelf, now: Date) async throws -> Board {
        // sortOrder は kind ごとに独立番号ではなく、全 Board 共通で単調増加（単純化のため）。
        let existing = try await boards.fetchAll()
        let nextOrder = (existing.map(\.sortOrder).max() ?? 0) + 1
        let board = try Board(kind: kind, name: name, createdAt: now, sortOrder: nextOrder)
        try await boards.save(board)
        return board
    }
}
