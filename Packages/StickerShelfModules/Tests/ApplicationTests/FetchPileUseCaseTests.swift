import Testing
import Foundation
@testable import Application
@testable import Domain

@Suite("FetchPileUseCase")
struct FetchPileUseCaseTests {
    @Test func sortsByAddedAtAscending_andIncludesStatistics() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let base = calendar.date(byAdding: .day, value: -5, to: now)!
        let earlier = calendar.date(byAdding: .day, value: -2, to: base)!

        let b1 = try Book(metadata: try BookMetadata(title: "古い"), status: .unread, addedAt: earlier)
        let b2 = try Book(metadata: try BookMetadata(title: "新しい"), status: .unread, addedAt: base)
        let onShelf = try Book(metadata: try BookMetadata(title: "本棚"), status: .reading, sticker: .init(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: 1), addedAt: base)

        let books = InMemoryBookRepository([b1, b2, onShelf])
        let useCase = FetchPileUseCase(books: books, statistics: TsundokuStatistics(calendar: calendar))
        let out = try await useCase.execute(now: now)
        #expect(out.books.map(\.metadata.title) == ["古い", "新しい"])
        #expect(out.statistics.count == 2)
    }

    @Test func filtersByBoardID_whenSpecified() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let folderA = BoardID()
        let folderB = BoardID()

        let a1 = try Book(metadata: try BookMetadata(title: "A1"), status: .unread, boardID: folderA, addedAt: now.addingTimeInterval(-3))
        let a2 = try Book(metadata: try BookMetadata(title: "A2"), status: .unread, boardID: folderA, addedAt: now.addingTimeInterval(-1))
        let b1 = try Book(metadata: try BookMetadata(title: "B1"), status: .unread, boardID: folderB, addedAt: now.addingTimeInterval(-2))
        let unassigned = try Book(metadata: try BookMetadata(title: "U1"), status: .unread, addedAt: now)

        let books = InMemoryBookRepository([a1, a2, b1, unassigned])
        let useCase = FetchPileUseCase(books: books, statistics: TsundokuStatistics(calendar: calendar))

        let onlyA = try await useCase.execute(boardID: folderA, now: now)
        #expect(onlyA.books.map(\.metadata.title) == ["A1", "A2"])
        // 統計は全体を母数にする
        #expect(onlyA.statistics.count == 4)

        let all = try await useCase.execute(boardID: nil, now: now)
        #expect(all.books.count == 4)
    }
}
