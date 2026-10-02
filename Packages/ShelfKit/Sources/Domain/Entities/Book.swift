import Foundation

public struct Book: Identifiable, Equatable, Sendable {
    public let id: BookID
    public private(set) var metadata: BookMetadata
    public private(set) var status: ReadingStatus
    public private(set) var period: ReadingPeriod
    public private(set) var progress: ReadingProgress
    public private(set) var purchase: PurchaseInfo
    public private(set) var memo: String
    public private(set) var sticker: StickerPlacement?
    public private(set) var stickerEdge: StickerEdge
    public private(set) var cover: CoverImage
    public let addedAt: Date

    public init(
        id: BookID = BookID(),
        metadata: BookMetadata,
        status: ReadingStatus = .unread,
        period: ReadingPeriod = .init(),
        progress: ReadingProgress = .init(),
        purchase: PurchaseInfo = .init(),
        memo: String = "",
        sticker: StickerPlacement? = nil,
        stickerEdge: StickerEdge = .white,
        cover: CoverImage = .none,
        addedAt: Date
    ) {
        self.id = id
        self.metadata = metadata
        self.status = status
        self.period = period
        self.progress = progress
        self.purchase = purchase
        self.memo = memo
        self.sticker = sticker
        self.stickerEdge = stickerEdge
        self.cover = cover
        self.addedAt = addedAt
    }

    /// ステータス遷移。
    /// - 要件:
    ///   - unread → reading/finished：`placement()` で新しい配置を生成する
    ///   - → unread：期間とステッカーをクリアする
    ///   - → reading：`startedAt ??= today`
    ///   - → finished：`finishedAt ??= today`、`startedAt ??= finishedAt`、`pageCount` があれば `currentPage = pageCount`
    public mutating func changeStatus(
        to new: ReadingStatus,
        on today: Date,
        placement: () -> StickerPlacement
    ) throws {
        let old = status
        status = new

        switch new {
        case .unread:
            period = .init()
            progress = .init()
            sticker = nil
        case .reading:
            if period.startedAt == nil {
                period.startedAt = today
            }
            if old == .unread {
                sticker = placement()
            }
        case .finished:
            if period.finishedAt == nil {
                period.finishedAt = today
            }
            if period.startedAt == nil {
                period.startedAt = period.finishedAt
            }
            if let total = metadata.pageCount {
                progress = ReadingProgress(currentPage: total)
            }
            if old == .unread {
                sticker = placement()
            }
            guard period.isValid() else { throw DomainError.invalidPeriod }
        }
    }

    public mutating func updatePeriod(startedAt: Date?, finishedAt: Date?) throws {
        let candidate = ReadingPeriod(startedAt: startedAt, finishedAt: finishedAt)
        guard candidate.isValid() else { throw DomainError.invalidPeriod }
        self.period = candidate
    }

    public mutating func updateProgress(currentPage: Int) throws {
        guard currentPage >= 0 else { throw DomainError.pageOutOfRange }
        if let total = metadata.pageCount, currentPage > total {
            throw DomainError.pageOutOfRange
        }
        self.progress = ReadingProgress(currentPage: currentPage)
    }

    public mutating func moveSticker(to placement: StickerPlacement) throws {
        guard status != .unread else { throw DomainError.stickerNotAllowedForUnread }
        self.sticker = placement
    }

    public mutating func updatePurchase(_ info: PurchaseInfo) {
        self.purchase = info
    }

    public mutating func updateMemo(_ text: String) {
        self.memo = text
    }

    public mutating func changeStickerEdge(_ edge: StickerEdge) {
        self.stickerEdge = edge
    }

    public mutating func replaceCover(_ cover: CoverImage) {
        self.cover = cover
    }

    public mutating func replaceMetadata(_ metadata: BookMetadata) {
        self.metadata = metadata
    }
}
