import Testing
import Foundation
import SwiftData
@testable import Infrastructure
@testable import Domain

@Suite("SwiftDataBoardRepository")
struct SwiftDataBoardRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([BoardRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func saveThenFetchRoundTrip_preservesKind() async throws {
        let container = try makeContainer()
        let repo = SwiftDataBoardRepository(modelContainer: container)

        let shelfBoard = try Board(kind: .shelf, name: "読んでる", createdAt: Date(), sortOrder: 1)
        let pileBoard = try Board(kind: .pile, name: "漫画", createdAt: Date(), sortOrder: 2)
        try await repo.save(shelfBoard)
        try await repo.save(pileBoard)

        let loadedShelf = try await repo.fetch(id: shelfBoard.id)
        let loadedPile = try await repo.fetch(id: pileBoard.id)
        #expect(loadedShelf?.kind == .shelf)
        #expect(loadedShelf?.name == "読んでる")
        #expect(loadedPile?.kind == .pile)
        #expect(loadedPile?.name == "漫画")
    }

    @Test func fetchAllKindFilters() async throws {
        let container = try makeContainer()
        let repo = SwiftDataBoardRepository(modelContainer: container)

        try await repo.save(try Board(kind: .shelf, name: "読んでる", createdAt: Date(), sortOrder: 1))
        try await repo.save(try Board(kind: .shelf, name: "読んだ", createdAt: Date(), sortOrder: 2))
        try await repo.save(try Board(kind: .pile, name: "あとで読む", createdAt: Date(), sortOrder: 3))
        try await repo.save(try Board(kind: .pile, name: "漫画", createdAt: Date(), sortOrder: 4))

        let shelf = try await repo.fetchAll(kind: .shelf)
        let pile = try await repo.fetchAll(kind: .pile)
        #expect(shelf.map(\.name) == ["読んでる", "読んだ"])
        #expect(pile.map(\.name) == ["あとで読む", "漫画"])
    }

    /// 既存ストア（kind カラム未保有）由来のレコードはデフォルトで .shelf として解釈される。
    @Test func legacyRecord_defaultsToShelf() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // kindRaw 省略で init（デフォルト "shelf"）
        let legacy = BoardRecord(id: UUID(), name: "古い本棚", createdAt: Date(), sortOrder: 1)
        context.insert(legacy)
        try context.save()

        let repo = SwiftDataBoardRepository(modelContainer: container)
        let loaded = try await repo.fetch(id: BoardID(legacy.id))
        #expect(loaded?.kind == .shelf)
    }
}
