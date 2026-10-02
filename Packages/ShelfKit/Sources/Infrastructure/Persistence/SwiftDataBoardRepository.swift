import Foundation
import SwiftData
import Domain

@ModelActor
public actor SwiftDataBoardRepository: BoardRepository {
    private let changesSubject = AsyncStreamSubject<Void>()

    public func fetchAll() async throws -> [Board] {
        let desc = FetchDescriptor<BoardRecord>(sortBy: [SortDescriptor(\.sortOrder, order: .forward)])
        let records = try modelContext.fetch(desc)
        return records.map { Board.reconstruct(id: BoardID($0.id), name: $0.name, createdAt: $0.createdAt, sortOrder: $0.sortOrder) }
    }

    public func fetch(id: BoardID) async throws -> Board? {
        let raw = id.rawValue
        let desc = FetchDescriptor<BoardRecord>(predicate: #Predicate { $0.id == raw })
        guard let record = try modelContext.fetch(desc).first else { return nil }
        return Board.reconstruct(id: BoardID(record.id), name: record.name, createdAt: record.createdAt, sortOrder: record.sortOrder)
    }

    public func save(_ board: Board) async throws {
        let raw = board.id.rawValue
        let desc = FetchDescriptor<BoardRecord>(predicate: #Predicate { $0.id == raw })
        if let existing = try modelContext.fetch(desc).first {
            existing.name = board.name
            existing.sortOrder = board.sortOrder
        } else {
            let record = BoardRecord(id: board.id.rawValue, name: board.name, createdAt: board.createdAt, sortOrder: board.sortOrder)
            modelContext.insert(record)
        }
        try modelContext.save()
        changesSubject.yield()
    }

    public func delete(id: BoardID) async throws {
        let raw = id.rawValue
        let desc = FetchDescriptor<BoardRecord>(predicate: #Predicate { $0.id == raw })
        if let record = try modelContext.fetch(desc).first {
            modelContext.delete(record)
            try modelContext.save()
            changesSubject.yield()
        }
    }

    public nonisolated func changes() -> AsyncStream<Void> {
        changesSubject.stream(initial: ())
    }
}
