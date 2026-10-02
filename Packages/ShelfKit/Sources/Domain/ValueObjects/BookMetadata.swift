import Foundation

public struct BookMetadata: Hashable, Sendable, Codable {
    public let title: String
    public let authors: [String]
    public let publisher: String?
    public let publishedDate: String?
    public let pageCount: Int?
    public let isbn: ISBN?
    public let remoteCoverURL: URL?
    public let catalogID: String?

    public init(
        title: String,
        authors: [String] = [],
        publisher: String? = nil,
        publishedDate: String? = nil,
        pageCount: Int? = nil,
        isbn: ISBN? = nil,
        remoteCoverURL: URL? = nil,
        catalogID: String? = nil
    ) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.invalidTitle }
        if let page = pageCount, page <= 0 {
            throw DomainError.pageOutOfRange
        }
        self.title = trimmed
        self.authors = authors
        self.publisher = publisher
        self.publishedDate = publishedDate
        self.pageCount = pageCount
        self.isbn = isbn
        self.remoteCoverURL = remoteCoverURL
        self.catalogID = catalogID
    }
}
