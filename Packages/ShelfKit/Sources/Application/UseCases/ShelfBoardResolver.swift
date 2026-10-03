import Foundation
import Domain

/// 本棚ステータス (`.reading` / `.finished`) に遷移した本を、適切な本棚側 Board に自動割当するヘルパー。
///
/// ルール：
/// - 新 status が `.unread` のときは何もしない（候補の `desiredBoardID` を尊重）
/// - 候補 `desiredBoardID` が shelf kind の Board を指しているなら、それを尊重して返す
/// - 候補 nil / pile Board を指す場合は、以下のフォールバック順で shelf Board を選ぶ
///     1. `.reading` → 名前が「読んでる」の shelf Board
///     2. `.finished` → 名前が「読んだ」の shelf Board
///     3. 1/2 で見つからなければ shelf Board の sortOrder 最小のもの
///     4. shelf Board が 1 つも無ければ nil（＝未分類で残す、以降の起動時に補充される）
public struct ShelfBoardResolver: Sendable {
    private let boards: BoardRepository

    public init(boards: BoardRepository) {
        self.boards = boards
    }

    public func resolve(status: ReadingStatus, desiredBoardID: BoardID?) async -> BoardID? {
        guard status != .unread else { return desiredBoardID }

        let shelfBoards = (try? await boards.fetchAll(kind: .shelf)) ?? []
        // 候補 ID が shelf kind を指しているならそれを採用。
        if let desired = desiredBoardID, shelfBoards.contains(where: { $0.id == desired }) {
            return desired
        }
        // ステータス名に対応する既定ボードがあればそちら。
        let preferredName: String = status == .reading ? "読んでる" : "読んだ"
        if let hit = shelfBoards.first(where: { $0.name == preferredName }) {
            return hit.id
        }
        // 最低限、何らかの shelf Board に落とす。
        return shelfBoards.first?.id
    }
}
