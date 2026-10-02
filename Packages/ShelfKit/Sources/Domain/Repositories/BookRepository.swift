import Foundation

public protocol BookRepository: Sendable {
    func fetchAll() async throws -> [Book]
    func fetch(id: BookID) async throws -> Book?
    func fetch(isbn: ISBN) async throws -> Book?
    func fetch(status: Set<ReadingStatus>) async throws -> [Book]
    func fetch(boardID: BoardID) async throws -> [Book]
    func fetchFinished(in interval: DateInterval) async throws -> [Book]
    func save(_ book: Book) async throws
    func saveAll(_ books: [Book]) async throws
    func delete(id: BookID) async throws
    func changes() -> AsyncStream<Void>
}
