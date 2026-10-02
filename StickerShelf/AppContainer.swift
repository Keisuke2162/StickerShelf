import Foundation
import SwiftData
import Domain
import Application
import Infrastructure
import Presentation

/// Composition Root。具象 Repository と UseCase を生成し PresentationContainer を組み立てる。
public struct AppContainer: Sendable {
    public let presentation: PresentationContainer
    public let startupOptions: StartupOptions

    public static func makeDefault(launchArguments: [String] = CommandLine.arguments) -> AppContainer {
        let options = StartupOptions.parse(from: launchArguments)

        let schema = Schema([BookRecord.self])
        // -SeedSampleData は「サンプルを追加投入」のためのフラグで、永続化の挙動とは切り離す。
        // ModelContainer 失敗時はインメモリにフォールバックして起動クラッシュを回避する。
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

        let bundleID = Bundle.main.bundleIdentifier ?? "com.example.StickerShelf"
        let fallback = InfoPlistAPIKeyProvider()
        let apiKeyRepository = KeychainAPIKeyRepository(service: bundleID, fallback: { fallback.load() })
        let searchPreferences = UserDefaultsSearchPreferenceRepository()

        let catalog: any BookCatalogRepository
        if options.useStubCatalog {
            catalog = StubCatalogRepositoryForLaunch()
        } else {
            let client = GoogleBooksClient(
                session: .shared,
                apiKeyProvider: { try? apiKeyRepository.load() },
                bundleID: bundleID
            )
            catalog = GoogleBooksCatalogRepository(client: client, preferences: searchPreferences)
        }

        let covers: any CoverImageRepository
        if let real = try? FileCoverImageRepository() {
            covers = real
        } else {
            // 書影ディレクトリ作成に失敗したら「書影は表示しない（none のみ）」の縮退モードに
            covers = NullCoverImageRepository()
        }

        let presentation = PresentationContainer(
            searchCatalog: SearchCatalogUseCase(catalog: catalog, books: bookRepository),
            findCatalogByISBN: FindCatalogBookByISBNUseCase(catalog: catalog),
            addBook: AddBookUseCase(books: bookRepository),
            fetchShelf: FetchShelfUseCase(books: bookRepository),
            fetchPile: FetchPileUseCase(books: bookRepository),
            fetchCalendar: FetchReadingCalendarUseCase(books: bookRepository),
            fetchBookDetail: FetchBookDetailUseCase(books: bookRepository),
            updateBookDetail: UpdateBookDetailUseCase(books: bookRepository),
            changeStatus: ChangeReadingStatusUseCase(books: bookRepository),
            moveSticker: MoveStickerUseCase(books: bookRepository),
            bringToFront: BringStickerToFrontUseCase(books: bookRepository),
            replaceCover: ReplaceCoverImageUseCase(books: bookRepository, covers: covers),
            deleteBook: DeleteBookUseCase(books: bookRepository, covers: covers),
            saveAPIKey: SaveAPIKeyUseCase(repository: apiKeyRepository),
            deleteAPIKey: DeleteAPIKeyUseCase(repository: apiKeyRepository),
            loadAPIKeyStatus: LoadAPIKeyStatusUseCase(repository: apiKeyRepository),
            testConnection: TestCatalogConnectionUseCase(catalog: catalog),
            searchPreferences: searchPreferences,
            coverImages: covers,
            bookChanges: { bookRepository.changes() }
        )

        let app = AppContainer(presentation: presentation, startupOptions: options)
        if options.seedSampleData {
            Task { await SampleDataSeeder.seed(into: bookRepository) }
        }
        return app
    }
}

/// FileCoverImageRepository 初期化に失敗したときのダミー。
struct NullCoverImageRepository: CoverImageRepository {
    func imageData(for cover: CoverImage) async throws -> Data? { nil }
    func saveUserImage(_ data: Data) async throws -> CoverImage { .none }
    func deleteLocal(_ cover: CoverImage) async throws {}
}

/// Phase 4 以降で UI プレビュー・UI テストから検索を試すためのネットワーク無しスタブ。
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
