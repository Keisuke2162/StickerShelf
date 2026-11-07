import Foundation

public enum DomainError: Error, Equatable, Sendable {
    case invalidTitle
    case invalidBoardName
    case invalidISBN
    case invalidPeriod
    case pageOutOfRange
    case stickerNotAllowedForUnread
    case duplicateBook(BookID)
    case bookNotFound(BookID)
    case catalogUnavailable(reason: String)
    case catalogQuotaExceeded
    case invalidAPIKey
    case network
}
