#if canImport(UIKit)
import Foundation
import Observation
import Domain
import Application

@MainActor
@Observable
public final class AddBookViewModel {
    public enum Destination: Hashable {
        case reading, finished, unread
        var status: ReadingStatus {
            switch self {
            case .reading: return .reading
            case .finished: return .finished
            case .unread: return .unread
            }
        }
    }

    public var keyword: String = ""
    public var destination: Destination = .unread
    public var purchasedAt: Date = Date()
    public private(set) var results: [SearchCatalogOutput.Item] = []
    public private(set) var isSearching = false
    public private(set) var isAdding = false
    public var selectedCatalog: CatalogBook?
    public var errorMessage: String?
    public var addedBook: Book?

    private let container: PresentationContainer
    private var searchTask: Task<Void, Never>?

    public init(container: PresentationContainer) {
        self.container = container
    }

    public func onKeywordChanged() {
        searchTask?.cancel()
        let keyword = self.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            results = []
            selectedCatalog = nil
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            await self?.search(keyword: keyword)
        }
    }

    public func search(keyword: String) async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let out = try await container.searchCatalog.execute(keyword: keyword, page: 0)
            results = out.items
        } catch is CancellationError {
            // デバウンスで前の検索を自分でキャンセルしたときは静かに戻る。
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
            results = []
        }
    }

    public func lookupISBN(_ isbn: ISBN) async {
        isSearching = true
        defer { isSearching = false }
        // SearchCatalog は ISBN 入力を自動判定して ISBN 検索 + 登録済み判定を返すので、そのまま流す。
        await search(keyword: isbn.value)
        if let first = results.first, !first.alreadyRegistered {
            selectedCatalog = first.catalog
        }
    }

    public func addSelected() async -> Book? {
        guard let selectedCatalog else { return nil }
        isAdding = true
        defer { isAdding = false }
        do {
            let input = AddBookInput(source: .catalog(selectedCatalog), initialStatus: destination.status, purchasedAt: purchasedAt, now: Date())
            let book = try await container.addBook.execute(input)
            addedBook = book
            return book
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
            return nil
        }
    }

    public func addManual(entry: AddBookInput.ManualEntry) async -> Book? {
        isAdding = true
        defer { isAdding = false }
        do {
            let input = AddBookInput(source: .manual(entry), initialStatus: destination.status, purchasedAt: purchasedAt, now: Date())
            let book = try await container.addBook.execute(input)
            addedBook = book
            return book
        } catch {
            errorMessage = DomainErrorMessage.describe(error)
            return nil
        }
    }
}

#endif
