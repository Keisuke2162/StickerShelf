import Foundation

/// ユーザーが作成する本棚ボード/積読フォルダ。`kind` で本棚側（.shelf）と積読側（.pile）を区別する。
public struct Board: Identifiable, Equatable, Sendable {
    public let id: BoardID
    public let kind: BoardKind
    public private(set) var name: String
    public let createdAt: Date
    public let sortOrder: Int

    public init(id: BoardID = BoardID(), kind: BoardKind = .shelf, name: String, createdAt: Date, sortOrder: Int) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.invalidBoardName }
        self.id = id
        self.kind = kind
        self.name = trimmed
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }

    public static func reconstruct(id: BoardID, kind: BoardKind = .shelf, name: String, createdAt: Date, sortOrder: Int) -> Board {
        Board(reconstructing: id, kind: kind, name: name, createdAt: createdAt, sortOrder: sortOrder)
    }

    private init(reconstructing id: BoardID, kind: BoardKind, name: String, createdAt: Date, sortOrder: Int) {
        self.id = id
        self.kind = kind
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
