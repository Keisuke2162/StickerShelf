import Foundation
import Domain

public struct GoogleBooksClient: Sendable {
    public let session: URLSession
    public let apiKeyProvider: @Sendable () -> APIKey?
    public let bundleID: String
    public let endpoint: URL

    public init(
        session: URLSession,
        apiKeyProvider: @escaping @Sendable () -> APIKey?,
        bundleID: String,
        endpoint: URL = URL(string: "https://www.googleapis.com/books/v1/volumes")!
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
        self.bundleID = bundleID
        self.endpoint = endpoint
    }

    func volumes(query: String, startIndex: Int, maxResults: Int, langRestrict: String?) async throws -> GoogleBooksVolumesResponseDTO {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            .init(name: "q", value: query),
            .init(name: "startIndex", value: String(startIndex)),
            .init(name: "maxResults", value: String(maxResults)),
            .init(name: "printType", value: "books"),
        ]
        if let langRestrict {
            items.append(.init(name: "langRestrict", value: langRestrict))
        }
        if let key = apiKeyProvider() {
            items.append(.init(name: "key", value: key.rawValue))
        }
        components.queryItems = items

        guard let url = components.url else {
            throw DomainError.catalogUnavailable(reason: "invalid URL")
        }
        var request = URLRequest(url: url)
        request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")

        let (data, response) = try await perform(request: request)
        try GoogleBooksErrorMapper.validate(response: response, data: data)
        return try JSONDecoder().decode(GoogleBooksVolumesResponseDTO.self, from: data)
    }

    private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            throw GoogleBooksErrorMapper.map(urlError: urlError)
        }
    }
}
