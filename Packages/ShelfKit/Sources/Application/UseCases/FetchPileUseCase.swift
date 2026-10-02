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
}

public struct FetchPileUseCase: FetchPileUseCaseProtocol {
    private let books: BookRepository
    private let statistics: TsundokuStatistics

    public init(books: BookRepository, statistics: TsundokuStatistics = .init()) {
        self.books = books
        self.statistics = statistics
    }

    public func execute(now: Date) async throws -> FetchPileOutput {
        let all = try await books.fetchAll()
        let unread = all
            .filter { $0.status == .unread }
            .sorted { $0.addedAt < $1.addedAt }
        // TsundokuStatistics.addedThisMonth は全ステータスを対象にするため all を渡す。
        let snapshot = statistics.snapshot(books: all, now: now)
        return FetchPileOutput(books: unread, statistics: snapshot)
    }
}
