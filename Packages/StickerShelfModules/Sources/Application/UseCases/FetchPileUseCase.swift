import Foundation
import Domain

public struct FetchPileOutput: Sendable {
    public let books: [Book]
    public let statistics: TsundokuStatistics.Snapshot

    public init(books: [Book], statistics: TsundokuStatistics.Snapshot) {
        self.books = books
        self.statistics = statistics
    }
}

public protocol FetchPileUseCaseProtocol: Sendable {
    func execute(now: Date) async throws -> FetchPileOutput
    func execute(boardID: BoardID?, now: Date) async throws -> FetchPileOutput
}

public struct FetchPileUseCase: FetchPileUseCaseProtocol {
    private let books: BookRepository
    private let statistics: TsundokuStatistics

    public init(books: BookRepository, statistics: TsundokuStatistics = .init()) {
        self.books = books
        self.statistics = statistics
    }

    public func execute(now: Date) async throws -> FetchPileOutput {
        try await execute(boardID: nil, now: now)
    }

    /// `boardID == nil` のときは全積読を返す。指定時は該当フォルダの積読のみ。
    /// 統計（addedThisMonth）はフォルダ絞り込みに関わらず全書籍を母数にする。
    public func execute(boardID: BoardID?, now: Date) async throws -> FetchPileOutput {
        let all = try await books.fetchAll()
        let unread = all
            .filter { $0.status == .unread }
            .filter { boardID == nil ? true : $0.boardID == boardID }
            .sorted { $0.addedAt < $1.addedAt }
        let snapshot = statistics.snapshot(books: all, now: now)
        return FetchPileOutput(books: unread, statistics: snapshot)
    }
}
