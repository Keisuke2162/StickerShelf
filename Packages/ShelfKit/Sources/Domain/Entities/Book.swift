import Foundation

public struct Book: Identifiable, Equatable, Sendable {
    public let id: BookID
    public private(set) var metadata: BookMetadata
    public private(set) var status: ReadingStatus
    public private(set) var period: ReadingPeriod
    public private(set) var progress: ReadingProgress
    public private(set) var purchase: PurchaseInfo
    public private(set) var memo: String
    /// `status == .unread` のときに限り nil。他のステータスでは必ず値を持つ。
    public private(set) var sticker: StickerPlacement?
    public private(set) var stickerEdge: StickerEdge
    public private(set) var cover: CoverImage
    /// 所属する本棚ボード。`status == .unread` では nil（積読は Board に属さない）。
    public private(set) var boardID: BoardID?
    public let addedAt: Date

    /// 新規作成用。不変条件を検証する。
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
        boardID: BoardID? = nil,
        addedAt: Date
    ) throws {
        if (status == .unread) != (sticker == nil) {
            throw DomainError.stickerNotAllowedForUnread
        }
        guard period.isValid() else { throw DomainError.invalidPeriod }
        if let total = metadata.pageCount, progress.currentPage > total {
            throw DomainError.pageOutOfRange
        }
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
        self.boardID = boardID
        self.addedAt = addedAt
    }

    /// 永続層からの再構築用。既にアプリ内で生成済みのデータを信頼して載せ替えるときのみ使う。
    public static func reconstruct(
        id: BookID,
        metadata: BookMetadata,
        status: ReadingStatus,
        period: ReadingPeriod,
        progress: ReadingProgress,
        purchase: PurchaseInfo,
        memo: String,
        sticker: StickerPlacement?,
        stickerEdge: StickerEdge,
        cover: CoverImage,
        boardID: BoardID?,
        addedAt: Date
    ) -> Book {
        Book(
            reconstructing: id,
            metadata: metadata,
            status: status,
            period: period,
            progress: progress,
            purchase: purchase,
            memo: memo,
            sticker: sticker,
            stickerEdge: stickerEdge,
            cover: cover,
            boardID: boardID,
            addedAt: addedAt
        )
    }

    private init(
        reconstructing id: BookID,
        metadata: BookMetadata,
        status: ReadingStatus,
        period: ReadingPeriod,
        progress: ReadingProgress,
        purchase: PurchaseInfo,
        memo: String,
        sticker: StickerPlacement?,
        stickerEdge: StickerEdge,
        cover: CoverImage,
        boardID: BoardID?,
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
        self.boardID = boardID
        self.addedAt = addedAt
    }

    public mutating func moveToBoard(_ boardID: BoardID?) {
        self.boardID = boardID
    }

    // MARK: - Behaviors

    /// ステータス遷移。遷移先に応じた期間・進捗・ステッカーの補完を行い、
    /// 検証を通ったあとにまとめて自身を書き換える（失敗時は副作用なし）。
    public mutating func changeStatus(
        to new: ReadingStatus,
        on today: Date,
        placement: () -> StickerPlacement
    ) throws {
        let old = status
        var nextPeriod = period
        var nextProgress = progress
        var nextSticker = sticker

        switch new {
        case .unread:
            nextPeriod = .init()
            nextProgress = .init()
            nextSticker = nil
        case .reading:
            if nextPeriod.startedAt == nil {
                nextPeriod.startedAt = today
            }
            if old == .unread {
                nextSticker = placement()
            }
        case .finished:
            if nextPeriod.finishedAt == nil {
                nextPeriod.finishedAt = today
            }
            if nextPeriod.startedAt == nil {
                nextPeriod.startedAt = nextPeriod.finishedAt
            }
            if let total = metadata.pageCount {
                nextProgress = ReadingProgress(currentPage: total)
            }
            if old == .unread {
                nextSticker = placement()
            }
        }

        guard nextPeriod.isValid() else { throw DomainError.invalidPeriod }

        self.status = new
        self.period = nextPeriod
        self.progress = nextProgress
        self.sticker = nextSticker
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
