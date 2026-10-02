import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("BookRecordMapper")
struct BookRecordMapperTests {
    private func baseRecord(id: UUID = UUID()) -> BookRecord {
        BookRecord(
            id: id,
            title: "テスト",
            authors: ["著者"],
            publisher: "出版社",
            publishedDate: "2024-05-01",
            pageCount: 320,
            isbnValue: "9784101010014",
            remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
            catalogID: "cat-001",
            statusRaw: "reading",
            startedAt: Date(timeIntervalSince1970: 1_770_000_000),
            finishedAt: nil,
            currentPage: 42,
            purchasedAt: Date(timeIntervalSince1970: 1_769_000_000),
            purchasePlace: "書店",
            memo: "メモ",
            stickerX: 0.5,
            stickerY: 0.4,
            stickerRotation: 10,
            stickerScale: 1.1,
            stickerZIndex: 3,
            stickerEdgeRaw: "holo",
            coverKind: "remote",
            coverRemoteURL: URL(string: "https://example.com/cover.jpg"),
            coverLocalFileName: nil,
            addedAt: Date(timeIntervalSince1970: 1_768_000_000)
        )
    }

    @Test func roundTrip() throws {
        let record = baseRecord()
        let book = try #require(BookRecordMapper.toDomain(record))
        #expect(book.metadata.title == "テスト")
        #expect(book.metadata.isbn?.value == "9784101010014")
        #expect(book.status == .reading)
        #expect(book.progress.currentPage == 42)
        #expect(book.sticker?.rotationDegrees == 10)
        #expect(book.stickerEdge == .holo)
    }

    @Test func recoversPageCountZero_byNullingIt() {
        let record = baseRecord()
        record.pageCount = 0
        let book = BookRecordMapper.toDomain(record)
        #expect(book != nil)
        #expect(book?.metadata.pageCount == nil)
    }

    @Test func dropsUnknownStatus() {
        let record = baseRecord()
        record.statusRaw = "garbage"
        #expect(BookRecordMapper.toDomain(record) == nil)
    }

    @Test func salvagesEmptyTitle() {
        let record = baseRecord()
        record.title = ""
        let book = BookRecordMapper.toDomain(record)
        #expect(book?.metadata.title == "(無題)")
    }

    @Test func stickerIsNilWhenStatusUnread() {
        let record = baseRecord()
        record.statusRaw = "unread"
        record.stickerX = 0.5
        record.stickerY = 0.5
        record.stickerRotation = 0
        record.stickerScale = 1
        record.stickerZIndex = 1
        let book = BookRecordMapper.toDomain(record)
        #expect(book?.sticker == nil)
    }
}
