import Testing
import Foundation
@testable import Application
@testable import Domain

@Suite("BringStickerToFrontUseCase")
struct BringStickerToFrontUseCaseTests {
    private func makeBook(z: Int, name: String = UUID().uuidString, addedAt: Date = Date()) throws -> Book {
        let meta = try BookMetadata(title: name)
        let sticker = StickerPlacement(x: 0.5, y: 0.5, rotationDegrees: 0, scale: 1, zIndex: z)
        return try Book(metadata: meta, status: .reading, sticker: sticker, addedAt: addedAt)
    }

    @Test func movesTargetToMaxZPlusOne() async throws {
        let a = try makeBook(z: 1, name: "A")
        let b = try makeBook(z: 2, name: "B")
        let c = try makeBook(z: 3, name: "C")
        let books = InMemoryBookRepository([a, b, c])
        let useCase = BringStickerToFrontUseCase(books: books)
        try await useCase.execute(id: a.id)
        let after = try await books.fetch(id: a.id)
        #expect(after?.sticker?.zIndex == 4)
    }

    @Test func compactsWhenAboveThreshold() async throws {
        let base = Date(timeIntervalSince1970: 1_770_000_000)
        var a = try makeBook(z: 9_999, addedAt: base)
        var b = try makeBook(z: 10_000, addedAt: base.addingTimeInterval(1))
        let books = InMemoryBookRepository([a, b])
        let useCase = BringStickerToFrontUseCase(books: books)
        try await useCase.execute(id: a.id)
        a = try await books.fetch(id: a.id)!
        b = try await books.fetch(id: b.id)!
        #expect(b.sticker?.zIndex == 1)
        #expect(a.sticker?.zIndex == 2)
    }
}
