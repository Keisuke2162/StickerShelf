#if canImport(UIKit)
import Foundation
import Domain

/// DEBUG 起動引数 `-SeedSampleData YES` のとき、本棚 18 冊 + 積読 23 冊を投入する。
public enum SampleDataSeeder {
    public static func seed(into repository: any BookRepository, boards: any BoardRepository) async {
        let now = Date()
        let factory = StickerPlacementFactory()
        var books: [Book] = []

        // 既存ボードから「読んでる」「読んだ」を取得。無ければ作る。
        var allBoards = (try? await boards.fetchAll()) ?? []
        func ensure(_ name: String, order: Int) async -> Board? {
            if let found = allBoards.first(where: { $0.name == name }) { return found }
            guard let created = try? Board(name: name, createdAt: now, sortOrder: order) else { return nil }
            try? await boards.save(created)
            allBoards.append(created)
            return created
        }
        guard let readingBoard = await ensure("読んでる", order: 1),
              let finishedBoard = await ensure("読んだ", order: 2) else { return }

        let shelfTitles = (0..<18).map { "本棚サンプル \($0 + 1)" }
        var existingZ: [Int] = []
        for title in shelfTitles {
            guard let meta = try? BookMetadata(title: title, authors: ["サンプル著者"], pageCount: 240) else { continue }
            let sticker = factory.make(existingZIndexes: existingZ)
            existingZ.append(sticker.zIndex)
            let status: ReadingStatus = Bool.random() ? .reading : .finished
            let period = status == .finished ? ReadingPeriod(startedAt: now, finishedAt: now) : ReadingPeriod(startedAt: now)
            let boardID = status == .finished ? finishedBoard.id : readingBoard.id
            if let book = try? Book(
                metadata: meta,
                status: status,
                period: period,
                progress: ReadingProgress(currentPage: status == .finished ? 240 : 120),
                sticker: sticker,
                boardID: boardID,
                addedAt: now.addingTimeInterval(-Double.random(in: 0...30) * 86400)
            ) {
                books.append(book)
            }
        }

        let pileTitles = (0..<23).map { "積読サンプル \($0 + 1)" }
        for title in pileTitles {
            guard let meta = try? BookMetadata(title: title, pageCount: 200) else { continue }
            if let book = try? Book(
                metadata: meta,
                status: .unread,
                purchase: PurchaseInfo(purchasedAt: now.addingTimeInterval(-Double.random(in: 0...60) * 86400)),
                addedAt: now.addingTimeInterval(-Double.random(in: 0...60) * 86400)
            ) {
                books.append(book)
            }
        }

        try? await repository.saveAll(books)
    }
}

#endif
