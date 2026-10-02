import Foundation

struct GoogleBooksVolumesResponseDTO: Decodable, Sendable {
    let totalItems: Int?
    let items: [GoogleBooksVolumeDTO]?
}

struct GoogleBooksVolumeDTO: Decodable, Sendable {
    let id: String?
    let volumeInfo: GoogleBooksVolumeInfoDTO?
}

struct GoogleBooksVolumeInfoDTO: Decodable, Sendable {
    let title: String?
    let subtitle: String?
    let authors: [String]?
    let publisher: String?
    let publishedDate: String?
    let pageCount: Int?
    let industryIdentifiers: [GoogleBooksIdentifierDTO]?
    let imageLinks: GoogleBooksImageLinksDTO?
}

struct GoogleBooksIdentifierDTO: Decodable, Sendable {
    let type: String?
    let identifier: String?
}

struct GoogleBooksImageLinksDTO: Decodable, Sendable {
    let smallThumbnail: String?
    let thumbnail: String?
}

struct GoogleBooksErrorBodyDTO: Decodable, Sendable {
    struct Error: Decodable, Sendable {
        struct Entry: Decodable, Sendable {
            let reason: String?
            let message: String?
        }
        struct Detail: Decodable, Sendable {
            let reason: String?
        }
        let code: Int?
        let message: String?
        let errors: [Entry]?
        let details: [Detail]?
        let status: String?
    }
    let error: Error?
}
