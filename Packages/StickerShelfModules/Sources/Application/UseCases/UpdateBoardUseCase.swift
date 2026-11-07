import Foundation
import Domain

public protocol UpdateBoardUseCaseProtocol: Sendable {
    func execute(id: BoardID, name: String, appearance: BoardAppearance) async throws -> Board
}

public struct UpdateBoardUseCase: UpdateBoardUseCaseProtocol {
    private let boards: BoardRepository

    public init(boards: BoardRepository) {
        self.boards = boards
    }

    public func execute(id: BoardID, name: String, appearance: BoardAppearance) async throws -> Board {
        guard var board = try await boards.fetch(id: id) else {
            // 既定の DomainError に該当するものがないので invalidBoardName に寄せず、個別エラーを後で検討。
            // 現状はシンプルに「ボードが見つからない」として invalidBoardName で妥協。
            throw DomainError.invalidBoardName
        }
        try board.rename(name)
        board.updateAppearance(appearance)
        try await boards.save(board)
        return board
    }
}
