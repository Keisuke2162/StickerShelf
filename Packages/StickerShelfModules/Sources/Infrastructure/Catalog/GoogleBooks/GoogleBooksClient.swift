import Foundation
import OSLog
import Domain

private let clientLogger = Logger(subsystem: "StickerShelf", category: "GoogleBooksClient")

public struct GoogleBooksClient: Sendable {
    public let session: URLSession
    public let apiKeyProvider: @Sendable () -> APIKey?
    public let bundleID: String
    public let endpoint: URL
    /// 429 / 5xx 発生時のリトライ待機（ナノ秒）。空なら無リトライ。
    public let retryDelays: [UInt64]
    public let sleep: @Sendable (UInt64) async -> Void

    public init(
        session: URLSession,
        apiKeyProvider: @escaping @Sendable () -> APIKey?,
        bundleID: String,
        endpoint: URL? = nil,
        retryDelays: [UInt64] = [500_000_000, 1_500_000_000],
        sleep: @escaping @Sendable (UInt64) async -> Void = { try? await Task.sleep(nanoseconds: $0) }
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
        self.bundleID = bundleID
        self.endpoint = endpoint ?? URL(string: "https://www.googleapis.com/books/v1/volumes").unsafelyUnwrapped
        self.retryDelays = retryDelays
        self.sleep = sleep
    }

    func volumes(query: String, startIndex: Int, maxResults: Int, langRestrict: String?) async throws -> GoogleBooksVolumesResponseDTO {
        let data = try await requestData(query: query, startIndex: startIndex, maxResults: maxResults, langRestrict: langRestrict)
        return try JSONDecoder().decode(GoogleBooksVolumesResponseDTO.self, from: data)
    }

    private func requestData(query: String, startIndex: Int, maxResults: Int, langRestrict: String?) async throws -> Data {
        let request = try makeRequest(query: query, startIndex: startIndex, maxResults: maxResults, langRestrict: langRestrict)
        var lastError: DomainError?

        for attempt in 0...retryDelays.count {
            do {
                let (data, response) = try await perform(request: request)
                try GoogleBooksErrorMapper.validate(response: response, data: data)
                return data
            } catch let error as DomainError {
                lastError = error
                if attempt < retryDelays.count, isRetryable(error) {
                    clientLogger.warning("retrying (attempt=\(attempt + 1)) due to \(String(describing: error), privacy: .public)")
                    await sleep(retryDelays[attempt])
                    continue
                }
                clientLogger.error("Google Books request failed: \(String(describing: error), privacy: .public)")
                throw error
            }
        }
        throw lastError ?? DomainError.catalogUnavailable(reason: "unknown")
    }

    private func makeRequest(query: String, startIndex: Int, maxResults: Int, langRestrict: String?) throws -> URLRequest {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw DomainError.catalogUnavailable(reason: "invalid endpoint")
        }
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
        // 一部の CDN が User-Agent 無しのリクエストを 400 で弾くことがあるため明示する。
        request.setValue("StickerShelf/1.0 iOS", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .cancelled {
                // デバウンス由来の自己キャンセルは Domain エラーに変換せず、そのまま呼び出し側に伝播する。
                clientLogger.debug("URL request cancelled")
                throw urlError
            }
            clientLogger.error("URLError: code=\(urlError.code.rawValue) description=\(urlError.localizedDescription, privacy: .public)")
            throw GoogleBooksErrorMapper.map(urlError: urlError)
        }
    }

    private func isRetryable(_ error: DomainError) -> Bool {
        // 400（bad request）や 403（APIキー不正・制限不一致）はリトライしても意味がない。
        // 429（quota）と 5xx 相当の `catalogUnavailable(reason:)` のうちサーバーエラーだけ再試行。
        switch error {
        case .catalogQuotaExceeded:
            return true
        case .catalogUnavailable(let reason):
            return reason.contains("server error")
        default:
            return false
        }
    }
}
