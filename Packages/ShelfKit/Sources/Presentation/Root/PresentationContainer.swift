#if canImport(UIKit)
import Foundation
import Domain
import Application

/// Presentation 層が UseCase 群と Repository へアクセスするための軽量コンテナ。
/// App ターゲットの `AppContainer` が具象実装を注入する。
public struct PresentationContainer: Sendable {
    public let searchCatalog: any SearchCatalogUseCaseProtocol
    public let findCatalogByISBN: any FindCatalogBookByISBNUseCaseProtocol
    public let addBook: any AddBookUseCaseProtocol
    public let fetchShelf: any FetchShelfUseCaseProtocol
    public let fetchPile: any FetchPileUseCaseProtocol
    public let fetchCalendar: any FetchReadingCalendarUseCaseProtocol
    public let fetchBookDetail: any FetchBookDetailUseCaseProtocol
    public let updateBookDetail: any UpdateBookDetailUseCaseProtocol
    public let changeStatus: any ChangeReadingStatusUseCaseProtocol
    public let moveSticker: any MoveStickerUseCaseProtocol
    public let bringToFront: any BringStickerToFrontUseCaseProtocol
    public let replaceCover: any ReplaceCoverImageUseCaseProtocol
    public let deleteBook: any DeleteBookUseCaseProtocol
    public let saveAPIKey: any SaveAPIKeyUseCaseProtocol
    public let deleteAPIKey: any DeleteAPIKeyUseCaseProtocol
    public let loadAPIKeyStatus: any LoadAPIKeyStatusUseCaseProtocol
    public let testConnection: any TestCatalogConnectionUseCaseProtocol
    public let searchPreferences: any SearchPreferenceRepository
    public let coverImages: any CoverImageRepository
    public let bookChanges: @Sendable () -> AsyncStream<Void>

    public init(
        searchCatalog: any SearchCatalogUseCaseProtocol,
        findCatalogByISBN: any FindCatalogBookByISBNUseCaseProtocol,
        addBook: any AddBookUseCaseProtocol,
        fetchShelf: any FetchShelfUseCaseProtocol,
        fetchPile: any FetchPileUseCaseProtocol,
        fetchCalendar: any FetchReadingCalendarUseCaseProtocol,
        fetchBookDetail: any FetchBookDetailUseCaseProtocol,
        updateBookDetail: any UpdateBookDetailUseCaseProtocol,
        changeStatus: any ChangeReadingStatusUseCaseProtocol,
        moveSticker: any MoveStickerUseCaseProtocol,
        bringToFront: any BringStickerToFrontUseCaseProtocol,
        replaceCover: any ReplaceCoverImageUseCaseProtocol,
        deleteBook: any DeleteBookUseCaseProtocol,
        saveAPIKey: any SaveAPIKeyUseCaseProtocol,
        deleteAPIKey: any DeleteAPIKeyUseCaseProtocol,
        loadAPIKeyStatus: any LoadAPIKeyStatusUseCaseProtocol,
        testConnection: any TestCatalogConnectionUseCaseProtocol,
        searchPreferences: any SearchPreferenceRepository,
        coverImages: any CoverImageRepository,
        bookChanges: @escaping @Sendable () -> AsyncStream<Void>
    ) {
        self.searchCatalog = searchCatalog
        self.findCatalogByISBN = findCatalogByISBN
        self.addBook = addBook
        self.fetchShelf = fetchShelf
        self.fetchPile = fetchPile
        self.fetchCalendar = fetchCalendar
        self.fetchBookDetail = fetchBookDetail
        self.updateBookDetail = updateBookDetail
        self.changeStatus = changeStatus
        self.moveSticker = moveSticker
        self.bringToFront = bringToFront
        self.replaceCover = replaceCover
        self.deleteBook = deleteBook
        self.saveAPIKey = saveAPIKey
        self.deleteAPIKey = deleteAPIKey
        self.loadAPIKeyStatus = loadAPIKeyStatus
        self.testConnection = testConnection
        self.searchPreferences = searchPreferences
        self.coverImages = coverImages
        self.bookChanges = bookChanges
    }
}

#endif
