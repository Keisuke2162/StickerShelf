import Foundation
import SwiftData
import Domain

@ModelActor
public actor SwiftDataMemoRepository: MemoRepository {
    private let changesSubject = AsyncStreamSubject<Void>()

    public func fetchAll() async throws -> [TitleMemo] {
        let desc = FetchDescriptor<MemoRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let records = try modelContext.fetch(desc)
        return records.map { TitleMemo.reconstruct(id: $0.id, title: $0.title, createdAt: $0.createdAt) }
    }

    public func save(_ memo: TitleMemo) async throws {
        let id = memo.id
        let desc = FetchDescriptor<MemoRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(desc).first {
            existing.title = memo.title
            existing.createdAt = memo.createdAt
        } else {
            modelContext.insert(MemoRecord(id: memo.id, title: memo.title, createdAt: memo.createdAt))
        }
        try modelContext.save()
        changesSubject.yield()
    }

    public func delete(id: UUID) async throws {
        let desc = FetchDescriptor<MemoRecord>(predicate: #Predicate { $0.id == id })
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
