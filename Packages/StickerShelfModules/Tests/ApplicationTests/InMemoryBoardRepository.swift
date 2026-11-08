import Foundation
import Domain

/// テスト用のメモリ内 BoardRepository。
public actor InMemoryBoardRepository: BoardRepository {
    private var storage: [BoardID: Board] = [:]
    nonisolated(unsafe) private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    nonisolated private let continuationsLock = NSLock()

    public init(_ boards: [Board] = []) {
        for b in boards { storage[b.id] = b }
    }

    public func fetchAll() async throws -> [Board] {
        storage.values.sorted { $0.sortOrder < $1.sortOrder }
    }

    public func fetch(id: BoardID) async throws -> Board? {
        storage[id]
    }

    public func save(_ board: Board) async throws {
        storage[board.id] = board
        broadcast()
    }

    public func delete(id: BoardID) async throws {
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
