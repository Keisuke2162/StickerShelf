import Foundation
import Domain

/// テスト用のメモリ内 BookRepository。
public actor InMemoryBookRepository: BookRepository {
    private var storage: [BookID: Book] = [:]
    nonisolated(unsafe) private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    nonisolated private let continuationsLock = NSLock()

    public init(_ books: [Book] = []) {
        for book in books { storage[book.id] = book }
    }

    public func fetchAll() async throws -> [Book] {
        storage.values.sorted { $0.addedAt < $1.addedAt }
    }

    public func fetch(id: BookID) async throws -> Book? {
        storage[id]
    }

    public func fetch(isbn: ISBN) async throws -> Book? {
        storage.values.first { $0.metadata.isbn == isbn }
    }

    public func fetch(status: Set<ReadingStatus>) async throws -> [Book] {
        storage.values.filter { status.contains($0.status) }.sorted { $0.addedAt < $1.addedAt }
    }

    public func fetchFinished(in interval: DateInterval) async throws -> [Book] {
        storage.values.filter { book in
            guard book.status == .finished, let date = book.period.finishedAt else { return false }
            return date >= interval.start && date < interval.end
        }
    }

    public func save(_ book: Book) async throws {
        storage[book.id] = book
        broadcast()
    }

    public func saveAll(_ books: [Book]) async throws {
        for b in books { storage[b.id] = b }
        broadcast()
    }

    public func delete(id: BookID) async throws {
        storage.removeValue(forKey: id)
        broadcast()
    }

    public nonisolated func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let token = UUID()
            self.continuationsLock.lock()
            self.continuations[token] = continuation
            self.continuationsLock.unlock()
            continuation.yield(())
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.continuationsLock.lock()
                self.continuations.removeValue(forKey: token)
                self.continuationsLock.unlock()
            }
        }
    }

    private nonisolated func broadcast() {
        continuationsLock.lock()
        let conts = Array(continuations.values)
        continuationsLock.unlock()
        for c in conts { c.yield(()) }
    }
}
