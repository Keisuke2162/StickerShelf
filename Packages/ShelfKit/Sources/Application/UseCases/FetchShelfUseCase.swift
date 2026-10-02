import Foundation
import Domain

public enum ShelfFilter: Sendable {
    case all
    case readingOnly
    case finishedOnly
}

public struct FetchShelfOutput: Sendable {
    public let books: [Book]
    public let counts: (reading: Int, finished: Int)

    public init(books: [Book], counts: (reading: Int, finished: Int)) {
        self.books = books
        self.counts = counts
    }
}

public protocol FetchShelfUseCaseProtocol: Sendable {
    func execute(filter: ShelfFilter) async throws -> FetchShelfOutput
}

public struct FetchShelfUseCase: FetchShelfUseCaseProtocol {
    private let books: BookRepository

    public init(books: BookRepository) {
        self.books = books
    }

    public func execute(filter: ShelfFilter) async throws -> FetchShelfOutput {
        let onShelf = try await books.fetch(status: [.reading, .finished])
        let reading = onShelf.filter { $0.status == .reading }
        let finished = onShelf.filter { $0.status == .finished }
        let selected: [Book]
        switch filter {
        case .all: selected = onShelf
        case .readingOnly: selected = reading
        case .finishedOnly: selected = finished
        }
        let sorted = selected.sorted { lhs, rhs in
            (lhs.sticker?.zIndex ?? 0) < (rhs.sticker?.zIndex ?? 0)
        }
        return FetchShelfOutput(books: sorted, counts: (reading.count, finished.count))
    }
}
