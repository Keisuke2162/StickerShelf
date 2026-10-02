import Foundation

/// ユーザーが作成する本棚ボード。読んでる/読んだ 等の既定ボードもここに含まれる。
public struct Board: Identifiable, Equatable, Sendable {
    public let id: BoardID
    public private(set) var name: String
    public let createdAt: Date
    public let sortOrder: Int

    public init(id: BoardID = BoardID(), name: String, createdAt: Date, sortOrder: Int) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.invalidBoardName }
        self.id = id
        self.name = trimmed
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }

    public static func reconstruct(id: BoardID, name: String, createdAt: Date, sortOrder: Int) -> Board {
        Board(reconstructing: id, name: name, createdAt: createdAt, sortOrder: sortOrder)
    }

    private init(reconstructing id: BoardID, name: String, createdAt: Date, sortOrder: Int) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }

    public mutating func rename(_ newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.invalidBoardName }
        self.name = trimmed
    }
}
