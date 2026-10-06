import Foundation
import SwiftData
import Domain

@ModelActor
public actor SwiftDataBoardRepository: BoardRepository {
    private let changesSubject = AsyncStreamSubject<Void>()

    public func fetchAll() async throws -> [Board] {
        let desc = FetchDescriptor<BoardRecord>(sortBy: [SortDescriptor(\.sortOrder, order: .forward)])
        let records = try modelContext.fetch(desc)
        return records.map(mapToDomain)
    }

    public func fetchAll(kind: BoardKind) async throws -> [Board] {
        let kindRaw = kind.rawValue
        let desc = FetchDescriptor<BoardRecord>(
            predicate: #Predicate { $0.kindRaw == kindRaw },
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        let records = try modelContext.fetch(desc)
        return records.map(mapToDomain)
    }

    public func fetch(id: BoardID) async throws -> Board? {
        let raw = id.rawValue
        let desc = FetchDescriptor<BoardRecord>(predicate: #Predicate { $0.id == raw })
        guard let record = try modelContext.fetch(desc).first else { return nil }
        return mapToDomain(record)
    }

    public func save(_ board: Board) async throws {
        let raw = board.id.rawValue
        let desc = FetchDescriptor<BoardRecord>(predicate: #Predicate { $0.id == raw })
        if let existing = try modelContext.fetch(desc).first {
            existing.name = board.name
            existing.sortOrder = board.sortOrder
            existing.kindRaw = board.kind.rawValue
            existing.appearanceColorRaw = board.appearance.color.rawValue
            existing.appearancePatternRaw = board.appearance.pattern.rawValue
        } else {
            let record = BoardRecord(
                id: board.id.rawValue,
                name: board.name,
                createdAt: board.createdAt,
                sortOrder: board.sortOrder,
                kindRaw: board.kind.rawValue,
                appearanceColorRaw: board.appearance.color.rawValue,
                appearancePatternRaw: board.appearance.pattern.rawValue
            )
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

    private func mapToDomain(_ record: BoardRecord) -> Board {
        let kind = BoardKind(rawValue: record.kindRaw) ?? .shelf
        let appearance = BoardAppearance(
            color: BoardColor(rawValue: record.appearanceColorRaw) ?? .cream,
            pattern: BoardPattern(rawValue: record.appearancePatternRaw) ?? .dots
        )
        return Board.reconstruct(
            id: BoardID(record.id),
            kind: kind,
            name: record.name,
            createdAt: record.createdAt,
            sortOrder: record.sortOrder,
            appearance: appearance
        )
    }
}
