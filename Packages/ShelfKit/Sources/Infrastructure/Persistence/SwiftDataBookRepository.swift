import Foundation
import SwiftData
import Domain

/// SwiftData による `BookRepository` 実装。
/// `@ModelActor` のバックグラウンドコンテキスト上で動作するため、スレッド安全。
@ModelActor
public actor SwiftDataBookRepository: BookRepository {
    private let changesSubject = AsyncStreamSubject<Void>()

    public func fetchAll() async throws -> [Book] {
        let desc = FetchDescriptor<BookRecord>(sortBy: [SortDescriptor(\.addedAt, order: .forward)])
        let records = try modelContext.fetch(desc)
        return records.compactMap(BookRecordMapper.toDomain)
    }

    public func fetch(id: BookID) async throws -> Book? {
        try fetchRecord(id: id).flatMap(BookRecordMapper.toDomain)
    }

    public func fetch(isbn: ISBN) async throws -> Book? {
        let value = isbn.value
        let desc = FetchDescriptor<BookRecord>(predicate: #Predicate { $0.isbnValue == value })
        let records = try modelContext.fetch(desc)
        return records.first.flatMap(BookRecordMapper.toDomain)
    }

    public func fetch(status: Set<ReadingStatus>) async throws -> [Book] {
        let raws = status.map { $0.rawValue }
        let desc = FetchDescriptor<BookRecord>(
            predicate: #Predicate { raws.contains($0.statusRaw) },
            sortBy: [SortDescriptor(\.addedAt, order: .forward)]
        )
        let records = try modelContext.fetch(desc)
        return records.compactMap(BookRecordMapper.toDomain)
    }

    public func fetchFinished(in interval: DateInterval) async throws -> [Book] {
        let start = interval.start
        let end = interval.end
        let finished = ReadingStatus.finished.rawValue
        let desc = FetchDescriptor<BookRecord>(
            predicate: #Predicate { record in
                record.statusRaw == finished &&
                record.finishedAt != nil &&
                record.finishedAt! >= start &&
                record.finishedAt! < end
            },
            sortBy: [SortDescriptor(\.finishedAt, order: .forward)]
        )
        let records = try modelContext.fetch(desc)
        return records.compactMap(BookRecordMapper.toDomain)
    }

    public func save(_ book: Book) async throws {
        if let existing = try fetchRecord(id: book.id) {
            BookRecordMapper.apply(book, to: existing)
        } else {
            let record = BookRecordMapper.makeRecord(book)
            modelContext.insert(record)
        }
        try modelContext.save()
        changesSubject.yield()
    }

    public func saveAll(_ books: [Book]) async throws {
        let ids = books.map { $0.id.rawValue }
        let desc = FetchDescriptor<BookRecord>(predicate: #Predicate { ids.contains($0.id) })
        let existing = try modelContext.fetch(desc)
        var byID: [UUID: BookRecord] = [:]
        for record in existing { byID[record.id] = record }

        for book in books {
            if let existing = byID[book.id.rawValue] {
                BookRecordMapper.apply(book, to: existing)
            } else {
                let record = BookRecordMapper.makeRecord(book)
                modelContext.insert(record)
            }
        }
        try modelContext.save()
        changesSubject.yield()
    }

    public func delete(id: BookID) async throws {
        if let record = try fetchRecord(id: id) {
            modelContext.delete(record)
            try modelContext.save()
            changesSubject.yield()
        }
    }

    public nonisolated func changes() -> AsyncStream<Void> {
        // 購読開始時に 1 回 yield することで、ViewModel 側は for-await ループひとつで初回ロード
        // + 以降の更新通知を扱える。
        changesSubject.stream(initial: ())
    }

    // MARK: - Private

    private func fetchRecord(id: BookID) throws -> BookRecord? {
        let raw = id.rawValue
        let desc = FetchDescriptor<BookRecord>(predicate: #Predicate { $0.id == raw })
        return try modelContext.fetch(desc).first
    }
}

/// 複数購読対応の軽量な AsyncStream ブロードキャスタ。
final class AsyncStreamSubject<Element: Sendable>: @unchecked Sendable {
    private struct State {
        var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]
    }

    private let lock = NSLock()
    private var state = State()

    func stream(initial: Element? = nil) -> AsyncStream<Element> {
        AsyncStream { continuation in
            let token = UUID()
            lock.lock()
            state.continuations[token] = continuation
            lock.unlock()
            if let initial {
                continuation.yield(initial)
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.state.continuations.removeValue(forKey: token)
                self.lock.unlock()
            }
        }
    }

    func yield(_ value: Element) {
        lock.lock()
        let continuations = Array(state.continuations.values)
        lock.unlock()
        for continuation in continuations {
            continuation.yield(value)
        }
    }
}

extension AsyncStreamSubject where Element == Void {
    func yield() { yield(()) }
}
