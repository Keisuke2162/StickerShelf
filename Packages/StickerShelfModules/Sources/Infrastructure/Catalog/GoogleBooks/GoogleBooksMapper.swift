import Foundation
import Domain

enum GoogleBooksMapper {
    static func toCatalogBook(_ volume: GoogleBooksVolumeDTO) -> CatalogBook? {
        guard let info = volume.volumeInfo, let rawTitle = info.title else { return nil }
        let title: String
        if let subtitle = info.subtitle, !subtitle.isEmpty {
            title = "\(rawTitle) \(subtitle)"
        } else {
            title = rawTitle
        }
        let page: Int? = (info.pageCount ?? 0) > 0 ? info.pageCount : nil
        let isbn: ISBN? = selectISBN(info.industryIdentifiers)
        let coverURL = normalizedCoverURL(info.imageLinks)

        guard let metadata = try? BookMetadata(
            title: title,
            authors: info.authors ?? [],
            publisher: info.publisher,
            publishedDate: info.publishedDate,
            pageCount: page,
            isbn: isbn,
            remoteCoverURL: coverURL,
            catalogID: volume.id
        ) else { return nil }
        return CatalogBook(metadata: metadata)
    }

    static func toCatalogSearchResult(_ dto: GoogleBooksVolumesResponseDTO, page: Int) -> CatalogSearchResult {
        let books = (dto.items ?? []).compactMap(toCatalogBook)
        return CatalogSearchResult(books: books, totalItems: dto.totalItems ?? 0, page: page)
    }

    private static func selectISBN(_ identifiers: [GoogleBooksIdentifierDTO]?) -> ISBN? {
        guard let identifiers else { return nil }
        if let isbn13 = identifiers.first(where: { $0.type == "ISBN_13" })?.identifier,
           let v = ISBN(isbn13) {
            return v
        }
        if let isbn10 = identifiers.first(where: { $0.type == "ISBN_10" })?.identifier,
           let v = ISBN(isbn10) {
            return v
        }
        return nil
    }

    private static func normalizedCoverURL(_ links: GoogleBooksImageLinksDTO?) -> URL? {
        let candidate = links?.thumbnail ?? links?.smallThumbnail
        guard let candidate else { return nil }
        var normalized = candidate
        if normalized.hasPrefix("http://") {
            normalized = "https://" + normalized.dropFirst("http://".count)
        }
        guard var components = URLComponents(string: normalized) else { return URL(string: normalized) }
        if let items = components.queryItems {
            let filtered = items.filter { $0.name != "edge" }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }
        return components.url
    }
}

