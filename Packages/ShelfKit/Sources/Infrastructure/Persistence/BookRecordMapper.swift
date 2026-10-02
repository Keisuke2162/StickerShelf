import Foundation
import OSLog
import Domain

private let mapperLogger = Logger(subsystem: "StickerShelf", category: "BookRecordMapper")

enum BookRecordMapper {
    static func toDomain(_ record: BookRecord) -> Book? {
        guard let status = ReadingStatus(rawValue: record.statusRaw) else {
            mapperLogger.warning("Dropping record \(record.id, privacy: .public): unknown status \(record.statusRaw, privacy: .public)")
            return nil
        }
        let edge = StickerEdge(rawValue: record.stickerEdgeRaw) ?? .white

        let metadata: BookMetadata
        do {
            // page_count が 0 以下だと BookMetadata が throw するため、保存値のゴミを吸収する。
            let normalizedPage: Int? = (record.pageCount ?? 0) > 0 ? record.pageCount : nil
            // タイトルが空のレコードはタイトル欠落として扱い、プレースホルダで救う。
            let title = record.title.isEmpty ? "(無題)" : record.title
            metadata = try BookMetadata(
                title: title,
                authors: record.authors,
                publisher: record.publisher,
                publishedDate: record.publishedDate,
                pageCount: normalizedPage,
                isbn: record.isbnValue.flatMap(ISBN.init),
                remoteCoverURL: record.remoteCoverURL,
                catalogID: record.catalogID
            )
        } catch {
            mapperLogger.error("Dropping record \(record.id, privacy: .public): metadata rebuild failed: \(String(describing: error), privacy: .public)")
            return nil
        }

        let period = ReadingPeriod(startedAt: record.startedAt, finishedAt: record.finishedAt)
        let progress = ReadingProgress(currentPage: record.currentPage)
        let purchase = PurchaseInfo(purchasedAt: record.purchasedAt, place: record.purchasePlace)

        let sticker: StickerPlacement?
        if status != .unread,
           let x = record.stickerX,
           let y = record.stickerY,
           let rot = record.stickerRotation,
           let scale = record.stickerScale,
           let z = record.stickerZIndex {
            sticker = StickerPlacement(x: x, y: y, rotationDegrees: rot, scale: scale, zIndex: z)
        } else {
            sticker = nil
        }

        let cover: CoverImage
        switch record.coverKind {
        case "remote":
            if let url = record.coverRemoteURL { cover = .remote(url) } else { cover = .none }
        case "local":
            if let name = record.coverLocalFileName { cover = .local(fileName: name) } else { cover = .none }
        default:
            cover = .none
        }

        return Book.reconstruct(
            id: BookID(record.id),
            metadata: metadata,
            status: status,
            period: period,
            progress: progress,
            purchase: purchase,
            memo: record.memo,
            sticker: sticker,
            stickerEdge: edge,
            cover: cover,
            addedAt: record.addedAt
        )
    }

    static func makeRecord(_ book: Book) -> BookRecord {
        let (kind, remote, local) = coverFields(book.cover)
        return BookRecord(
            id: book.id.rawValue,
            title: book.metadata.title,
            authors: book.metadata.authors,
            publisher: book.metadata.publisher,
            publishedDate: book.metadata.publishedDate,
            pageCount: book.metadata.pageCount,
            isbnValue: book.metadata.isbn?.value,
            remoteCoverURL: book.metadata.remoteCoverURL,
            catalogID: book.metadata.catalogID,
            statusRaw: book.status.rawValue,
            startedAt: book.period.startedAt,
            finishedAt: book.period.finishedAt,
            currentPage: book.progress.currentPage,
            purchasedAt: book.purchase.purchasedAt,
            purchasePlace: book.purchase.place,
            memo: book.memo,
            stickerX: book.sticker?.x,
            stickerY: book.sticker?.y,
            stickerRotation: book.sticker?.rotationDegrees,
            stickerScale: book.sticker?.scale,
            stickerZIndex: book.sticker?.zIndex,
            stickerEdgeRaw: book.stickerEdge.rawValue,
            coverKind: kind,
            coverRemoteURL: remote,
            coverLocalFileName: local,
            addedAt: book.addedAt
        )
    }

    static func apply(_ book: Book, to record: BookRecord) {
        record.title = book.metadata.title
        record.authors = book.metadata.authors
        record.publisher = book.metadata.publisher
        record.publishedDate = book.metadata.publishedDate
        record.pageCount = book.metadata.pageCount
        record.isbnValue = book.metadata.isbn?.value
        record.remoteCoverURL = book.metadata.remoteCoverURL
        record.catalogID = book.metadata.catalogID
        record.statusRaw = book.status.rawValue
        record.startedAt = book.period.startedAt
        record.finishedAt = book.period.finishedAt
        record.currentPage = book.progress.currentPage
        record.purchasedAt = book.purchase.purchasedAt
        record.purchasePlace = book.purchase.place
        record.memo = book.memo
        record.stickerX = book.sticker?.x
        record.stickerY = book.sticker?.y
        record.stickerRotation = book.sticker?.rotationDegrees
        record.stickerScale = book.sticker?.scale
        record.stickerZIndex = book.sticker?.zIndex
        record.stickerEdgeRaw = book.stickerEdge.rawValue
        let (kind, remote, local) = coverFields(book.cover)
        record.coverKind = kind
        record.coverRemoteURL = remote
        record.coverLocalFileName = local
    }

    private static func coverFields(_ cover: CoverImage) -> (String, URL?, String?) {
        switch cover {
        case .remote(let url): return ("remote", url, nil)
        case .local(let name): return ("local", nil, name)
        case .none: return ("none", nil, nil)
        }
    }
}
