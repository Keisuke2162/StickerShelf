import Foundation

public protocol MemoRepository: Sendable {
    func fetchAll() async throws -> [TitleMemo]
    func save(_ memo: TitleMemo) async throws
    func delete(id: UUID) async throws
    func changes() -> AsyncStream<Void>
}
