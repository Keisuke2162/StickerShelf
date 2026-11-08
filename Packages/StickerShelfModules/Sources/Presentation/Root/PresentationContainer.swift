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
    public let fetchBoards: any FetchBoardsUseCaseProtocol
    public let createBoard: any CreateBoardUseCaseProtocol
    public let updateBoard: any UpdateBoardUseCaseProtocol
    public let deleteBoard: any DeleteBoardUseCaseProtocol
    public let moveBookToBoard: any MoveBookToBoardUseCaseProtocol
    public let markAsRead: any MarkAsReadUseCaseProtocol
    public let unmarkAsRead: any UnmarkAsReadUseCaseProtocol
    public let addMemo: any AddMemoUseCaseProtocol
    public let fetchMemos: any FetchMemosUseCaseProtocol
    public let deleteMemo: any DeleteMemoUseCaseProtocol
    public let searchPreferences: any SearchPreferenceRepository
    public let themePreferences: any ThemePreferenceRepository
    public let coverImages: any CoverImageRepository
    public let bookChanges: @Sendable () -> AsyncStream<Void>
    public let boardChanges: @Sendable () -> AsyncStream<Void>
    public let memoChanges: @Sendable () -> AsyncStream<Void>

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
        fetchBoards: any FetchBoardsUseCaseProtocol,
        createBoard: any CreateBoardUseCaseProtocol,
        updateBoard: any UpdateBoardUseCaseProtocol,
        deleteBoard: any DeleteBoardUseCaseProtocol,
        moveBookToBoard: any MoveBookToBoardUseCaseProtocol,
        markAsRead: any MarkAsReadUseCaseProtocol,
        unmarkAsRead: any UnmarkAsReadUseCaseProtocol,
        addMemo: any AddMemoUseCaseProtocol,
        fetchMemos: any FetchMemosUseCaseProtocol,
        deleteMemo: any DeleteMemoUseCaseProtocol,
        searchPreferences: any SearchPreferenceRepository,
        themePreferences: any ThemePreferenceRepository,
        coverImages: any CoverImageRepository,
        bookChanges: @escaping @Sendable () -> AsyncStream<Void>,
        boardChanges: @escaping @Sendable () -> AsyncStream<Void>,
        memoChanges: @escaping @Sendable () -> AsyncStream<Void>
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
        self.fetchBoards = fetchBoards
        self.createBoard = createBoard
        self.updateBoard = updateBoard
        self.deleteBoard = deleteBoard
        self.moveBookToBoard = moveBookToBoard
        self.markAsRead = markAsRead
        self.unmarkAsRead = unmarkAsRead
        self.addMemo = addMemo
        self.fetchMemos = fetchMemos
        self.deleteMemo = deleteMemo
        self.searchPreferences = searchPreferences
        self.themePreferences = themePreferences
        self.coverImages = coverImages
        self.bookChanges = bookChanges
        self.boardChanges = boardChanges
        self.memoChanges = memoChanges
    }
}

#endif
