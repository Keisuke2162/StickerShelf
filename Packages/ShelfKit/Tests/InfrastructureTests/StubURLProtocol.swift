import Foundation

/// テスト用に URL リクエストをスタブ応答で解決する URLProtocol。
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        let statusCode: Int
        let data: Data
        let headers: [String: String]

        init(statusCode: Int = 200, data: Data = Data(), headers: [String: String] = [:]) {
            self.statusCode = statusCode
            self.data = data
            self.headers = headers
        }
    }

    nonisolated(unsafe) private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: (@Sendable (URLRequest) throws -> Response)?
    nonisolated(unsafe) private static var seenRequests: [URLRequest] = []

    static func install(_ handler: @escaping @Sendable (URLRequest) throws -> Response) {
        lock.lock()
        defer { lock.unlock() }
        Self.handler = handler
        Self.seenRequests = []
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        Self.handler = nil
        Self.seenRequests = []
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return Self.seenRequests
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.seenRequests.append(request)
        let handler = Self.handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        do {
            let response = try handler(request)
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLSession {
    static func stubbed(_ handler: @escaping @Sendable (URLRequest) throws -> StubURLProtocol.Response) -> URLSession {
        StubURLProtocol.install(handler)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}
