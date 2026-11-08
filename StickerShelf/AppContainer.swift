import Foundation
import SwiftData
import Domain
import Application
import Infrastructure
import Presentation

/// アプリ全体の依存関係を一箇所で組み立てる Composition Root。
/// SwiftData・各種 Repository・UseCase を生成して PresentationContainer にまとめる。
public struct AppContainer: Sendable {
    public let presentation: PresentationContainer
    public let startupOptions: StartupOptions

    public static func makeDefault(launchArguments: [String] = CommandLine.arguments) -> AppContainer {
        let options = StartupOptions.parse(from: launchArguments)

        let schema = Schema([BookRecord.self, BoardRecord.self, MemoRecord.self])
        // SwiftData の保存先を作る。通常はディスクに永続化、作成に失敗した端末では
        // インメモリで起動して少なくとも今セッションの利用は継続できるようにする。
        let container: ModelContainer = {
            if let normal = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]) {
                return normal
            }
            if let fallback = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]) {
                return fallback
            }
            fatalError("ModelContainer could not be created at all")
        }()

        let bookRepository = SwiftDataBookRepository(modelContainer: container)
        let boardRepository = SwiftDataBoardRepository(modelContainer: container)
        let memoRepository = SwiftDataMemoRepository(modelContainer: container)

        let bundleID = Bundle.main.bundleIdentifier ?? "com.example.StickerShelf"
        let fallback = InfoPlistAPIKeyProvider()
        let apiKeyRepository = KeychainAPIKeyRepository(service: bundleID, fallback: { fallback.load() })
        let searchPreferences = UserDefaultsSearchPreferenceRepository()
        let themePreferences = UserDefaultsThemePreferenceRepository()

        let catalog: any BookCatalogRepository
        if options.useStubCatalog {
            catalog = StubCatalogRepositoryForLaunch()
        } else {
          // Cloudflareworkers上のbook-api
          let client = BookAPIClient(
            session: .shared,
            baseURL: URL(string: "https://book-api.kei3islands-books.workers.dev").unsafelyUnwrapped
          )
          catalog = BookAPICatalogRepository(client: client)
        }

        // 書影はローカルのディレクトリに保存する。もしそのディレクトリを用意できない環境なら、
        // 書影機能なし（常に .none を返す）のダミー実装で起動を続ける。
        let covers: any CoverImageRepository
        if let real = try? FileCoverImageRepository() {
            covers = real
        } else {
            covers = NullCoverImageRepository()
        }

        let shelfResolver = ShelfBoardResolver(boards: boardRepository)
        let presentation = PresentationContainer(
            searchCatalog: SearchCatalogUseCase(catalog: catalog, books: bookRepository),
            findCatalogByISBN: FindCatalogBookByISBNUseCase(catalog: catalog),
            addBook: AddBookUseCase(books: bookRepository),
            fetchShelf: FetchShelfUseCase(books: bookRepository),
            fetchPile: FetchPileUseCase(books: bookRepository),
            fetchCalendar: FetchReadingCalendarUseCase(books: bookRepository),
            fetchBookDetail: FetchBookDetailUseCase(books: bookRepository),
            updateBookDetail: UpdateBookDetailUseCase(books: bookRepository, shelfResolver: shelfResolver),
            changeStatus: ChangeReadingStatusUseCase(books: bookRepository, shelfResolver: shelfResolver),
            moveSticker: MoveStickerUseCase(books: bookRepository),
            bringToFront: BringStickerToFrontUseCase(books: bookRepository),
            replaceCover: ReplaceCoverImageUseCase(books: bookRepository, covers: covers),
            deleteBook: DeleteBookUseCase(books: bookRepository, covers: covers),
            saveAPIKey: SaveAPIKeyUseCase(repository: apiKeyRepository),
            deleteAPIKey: DeleteAPIKeyUseCase(repository: apiKeyRepository),
            loadAPIKeyStatus: LoadAPIKeyStatusUseCase(repository: apiKeyRepository),
            testConnection: TestCatalogConnectionUseCase(catalog: catalog),
            fetchBoards: FetchBoardsUseCase(boards: boardRepository),
            createBoard: CreateBoardUseCase(boards: boardRepository),
            updateBoard: UpdateBoardUseCase(boards: boardRepository),
            deleteBoard: DeleteBoardUseCase(boards: boardRepository, books: bookRepository),
            moveBookToBoard: MoveBookToBoardUseCase(books: bookRepository),
            markAsRead: MarkAsReadUseCase(books: bookRepository),
            unmarkAsRead: UnmarkAsReadUseCase(books: bookRepository),
            addMemo: AddMemoUseCase(memos: memoRepository),
            fetchMemos: FetchMemosUseCase(memos: memoRepository),
            deleteMemo: DeleteMemoUseCase(memos: memoRepository),
            searchPreferences: searchPreferences,
            themePreferences: themePreferences,
            coverImages: covers,
            bookChanges: { bookRepository.changes() },
            boardChanges: { boardRepository.changes() },
            memoChanges: { memoRepository.changes() }
        )

        let app = AppContainer(presentation: presentation, startupOptions: options)
        // 初回起動時や既定ボードがユーザーに削除されていた場合に備え、
        // 「読んでる」「読んだ」が無ければ作成しておく（毎回起動時に確認）。
        Task { await ensureDefaultBoards(repository: boardRepository, books: bookRepository) }
        if options.seedSampleData {
            Task { await SampleDataSeeder.seed(into: bookRepository, boards: boardRepository) }
        }
        return app
    }

    /// 既定ボード「読んでる」「読んだ」を用意する。
    /// 既に両方あれば何もせず、片方だけ無ければその片方だけ作る（何度呼んでも安全）。
    /// また、まだ所属ボードが決まっていない「読書中」「読了」の本は、対応する既定ボードへ割り当てる。
    private static func ensureDefaultBoards(repository: SwiftDataBoardRepository, books: SwiftDataBookRepository) async {
        let existing = (try? await repository.fetchAll()) ?? []
        let now = Date()
        let shelfBoards = existing.filter { $0.kind == .shelf }
        let maxOrder = existing.map(\.sortOrder).max() ?? 0

        var readingBoard = shelfBoards.first { $0.name == "読んでる" }
        if readingBoard == nil {
            let created = try? Board(kind: .shelf, name: "読んでる", createdAt: now, sortOrder: maxOrder + 1)
            if let created {
                try? await repository.save(created)
                readingBoard = created
            }
        }

        var finishedBoard = shelfBoards.first { $0.name == "読んだ" }
        if finishedBoard == nil {
            let nextOrder = (readingBoard?.sortOrder ?? maxOrder) + 1
            let created = try? Board(kind: .shelf, name: "読んだ", createdAt: now, sortOrder: nextOrder)
            if let created {
                try? await repository.save(created)
                finishedBoard = created
            }
        }

        guard let readingBoard, let finishedBoard else { return }

        if let all = try? await books.fetchAll() {
            var migrated: [Book] = []
            for var book in all {
                guard book.boardID == nil else { continue }
                switch book.status {
                case .reading:
                    book.moveToBoard(readingBoard.id)
                    migrated.append(book)
                case .finished:
                    book.moveToBoard(finishedBoard.id)
                    migrated.append(book)
                case .unread:
                    continue
                }
            }
            if !migrated.isEmpty {
                try? await books.saveAll(migrated)
            }
        }
    }
}

/// 書影保存ディレクトリを用意できない環境向けのフォールバック。
/// 常に「書影なし（.none）」を返し、保存操作も何もしない。
struct NullCoverImageRepository: CoverImageRepository {
    func imageData(for cover: CoverImage) async throws -> Data? { nil }
    func saveUserImage(_ data: Data) async throws -> CoverImage { .none }
    func deleteLocal(_ cover: CoverImage) async throws {}
}

/// 起動引数 `-UseStubCatalog YES` で差し込むダミーの書籍検索実装。
/// ネットワークを呼ばず固定のサンプルを返すので、UI プレビュー・UI テスト・オフライン確認に使う。
struct StubCatalogRepositoryForLaunch: BookCatalogRepository {
    func search(keyword: String, page: Int) async throws -> CatalogSearchResult {
        let samples: [CatalogBook] = [
            try sample("スタブ検索結果 \(keyword)", isbn: "9784101010014"),
        ]
        return CatalogSearchResult(books: samples, totalItems: samples.count, page: page)
    }

    func find(isbn: ISBN) async throws -> CatalogBook? {
        try sample("スタブ ISBN 本", isbn: isbn.value)
    }

    private func sample(_ title: String, isbn: String) throws -> CatalogBook {
        try CatalogBook(metadata: BookMetadata(title: title, authors: ["スタブ著者"], pageCount: 200, isbn: ISBN(isbn)))
    }
}
