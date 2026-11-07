import Foundation
import Domain

public protocol FetchBoardsUseCaseProtocol: Sendable {
    func execute() async throws -> [Board]
    func execute(kind: BoardKind) async throws -> [Board]
}

public struct FetchBoardsUseCase: FetchBoardsUseCaseProtocol {
    private let boards: BoardRepository

    public init(boards: BoardRepository) {
        self.boards = boards
    }

    public func execute() async throws -> [Board] {
        try await boards.fetchAll()
    }

    public func execute(kind: BoardKind) async throws -> [Board] {
        try await boards.fetchAll(kind: kind)
    }
}
