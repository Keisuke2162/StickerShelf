import Foundation
import Domain

public protocol AddMemoUseCaseProtocol: Sendable {
    func execute(title: String, now: Date) async throws -> TitleMemo
}

public struct AddMemoUseCase: AddMemoUseCaseProtocol {
    private let memos: MemoRepository

    public init(memos: MemoRepository) {
        self.memos = memos
    }

    public func execute(title: String, now: Date) async throws -> TitleMemo {
        let memo = try TitleMemo(title: title, createdAt: now)
        try await memos.save(memo)
        return memo
    }
}

public protocol FetchMemosUseCaseProtocol: Sendable {
    func execute() async throws -> [TitleMemo]
}

public struct FetchMemosUseCase: FetchMemosUseCaseProtocol {
    private let memos: MemoRepository

    public init(memos: MemoRepository) {
        self.memos = memos
    }

    public func execute() async throws -> [TitleMemo] {
        try await memos.fetchAll()
    }
}

public protocol DeleteMemoUseCaseProtocol: Sendable {
    func execute(id: UUID) async throws
}

public struct DeleteMemoUseCase: DeleteMemoUseCaseProtocol {
    private let memos: MemoRepository

    public init(memos: MemoRepository) {
        self.memos = memos
    }

    public func execute(id: UUID) async throws {
        try await memos.delete(id: id)
    }
}
