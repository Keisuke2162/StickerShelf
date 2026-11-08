import Foundation
import Domain

public protocol FetchBookDetailUseCaseProtocol: Sendable {
    func execute(id: BookID) async throws -> Book?
}

public struct FetchBookDetailUseCase: FetchBookDetailUseCaseProtocol {
    private let books: BookRepository

    public init(books: BookRepository) {
        self.books = books
    }

    public func execute(id: BookID) async throws -> Book? {
        try await books.fetch(id: id)
    }
}
