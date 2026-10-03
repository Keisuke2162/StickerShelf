import Foundation

public protocol BoardRepository: Sendable {
    func fetchAll() async throws -> [Board]
    func fetchAll(kind: BoardKind) async throws -> [Board]
    func fetch(id: BoardID) async throws -> Board?
    func save(_ board: Board) async throws
    func delete(id: BoardID) async throws
    func changes() -> AsyncStream<Void>
}

public extension BoardRepository {
    func fetchAll(kind: BoardKind) async throws -> [Board] {
        try await fetchAll().filter { $0.kind == kind }
    }
}
