import Foundation
import SwiftData

/// SwiftData に永続化する本の 1 レコード。
/// Domain の `Book` とは `BookRecordMapper` を介してのみ変換する（Domain を漏らさない）。
///
/// 将来 CloudKit 同期を有効にするときに「全プロパティは optional か default 値を持つ」
/// 制約を満たすため、unique id 以外にはデフォルト値を与えてある。
@Model
public final class BookRecord {
    @Attribute(.unique) public var id: UUID = UUID()
    public var title: String = ""
    public var authors: [String] = []
    public var publisher: String?
    public var publishedDate: String?
    public var pageCount: Int?
    public var isbnValue: String?
    public var remoteCoverURL: URL?
    public var catalogID: String?

    public var statusRaw: String = "unread"
    public var startedAt: Date?
    public var finishedAt: Date?
    public var currentPage: Int = 0

    public var purchasedAt: Date?
    public var purchasePlace: String = ""
    public var memo: String = ""

    public var stickerX: Double?
    public var stickerY: Double?
    public var stickerRotation: Double?
    public var stickerScale: Double?
    public var stickerZIndex: Int?

    public var stickerEdgeRaw: String = "white"

    /// 書影：種類（`remote` / `local` / `none`）
    public var coverKind: String = "none"
    public var coverRemoteURL: URL?
    public var coverLocalFileName: String?

    /// 所属するボードの ID（unread 本は nil）。
    public var boardIDValue: UUID?

    public var addedAt: Date = Date(timeIntervalSince1970: 0)

    public init(
        id: UUID,
        title: String,
        authors: [String],
        publisher: String?,
        publishedDate: String?,
        pageCount: Int?,
        isbnValue: String?,
        remoteCoverURL: URL?,
        catalogID: String?,
        statusRaw: String,
        startedAt: Date?,
        finishedAt: Date?,
        currentPage: Int,
        purchasedAt: Date?,
        purchasePlace: String,
        memo: String,
        stickerX: Double?,
        stickerY: Double?,
        stickerRotation: Double?,
        stickerScale: Double?,
        stickerZIndex: Int?,
        stickerEdgeRaw: String,
        coverKind: String,
        coverRemoteURL: URL?,
        coverLocalFileName: String?,
        boardIDValue: UUID?,
        addedAt: Date
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.publisher = publisher
        self.publishedDate = publishedDate
        self.pageCount = pageCount
        self.isbnValue = isbnValue
        self.remoteCoverURL = remoteCoverURL
        self.catalogID = catalogID
        self.statusRaw = statusRaw
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.currentPage = currentPage
        self.purchasedAt = purchasedAt
        self.purchasePlace = purchasePlace
        self.memo = memo
        self.stickerX = stickerX
        self.stickerY = stickerY
        self.stickerRotation = stickerRotation
        self.stickerScale = stickerScale
        self.stickerZIndex = stickerZIndex
        self.stickerEdgeRaw = stickerEdgeRaw
        self.coverKind = coverKind
        self.coverRemoteURL = coverRemoteURL
        self.coverLocalFileName = coverLocalFileName
        self.boardIDValue = boardIDValue
        self.addedAt = addedAt
    }
}
