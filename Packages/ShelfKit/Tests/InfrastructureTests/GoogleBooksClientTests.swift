import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("GoogleBooksClient", .serialized)
struct GoogleBooksClientTests {
    private func makeClient(session: URLSession, apiKey: String? = "test-key-1234") -> GoogleBooksClient {
        GoogleBooksClient(
            session: session,
            apiKeyProvider: { apiKey.flatMap(APIKey.init) },
            bundleID: "com.example.app",
            retryDelays: [],
            sleep: { _ in }
        )
    }

    @Test func includesBundleHeader_andAttachesKey_whenPresent() async throws {
        let fixture = try FixtureLoader.data("volumes_search_normal")
        let session = URLSession.stubbed { _ in .init(statusCode: 200, data: fixture) }
        let client = makeClient(session: session)
        _ = try await client.volumes(query: "宇宙", startIndex: 0, maxResults: 20, langRestrict: "ja")
        let seen = StubURLProtocol.recordedRequests()
        #expect(seen.count == 1)
        let url = seen[0].url!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(components.queryItems?.contains(where: { $0.name == "key" && $0.value == "test-key-1234" }) == true)
        #expect(components.queryItems?.contains(where: { $0.name == "langRestrict" && $0.value == "ja" }) == true)
        #expect(seen[0].value(forHTTPHeaderField: "X-Ios-Bundle-Identifier") == "com.example.app")
    }

    @Test func omitsKey_whenNil_andOmitsLang_whenNil() async throws {
        let fixture = try FixtureLoader.data("volumes_empty")
        let session = URLSession.stubbed { _ in .init(statusCode: 200, data: fixture) }
        let client = makeClient(session: session, apiKey: nil)
        _ = try await client.volumes(query: "foo", startIndex: 0, maxResults: 20, langRestrict: nil)
        let seen = StubURLProtocol.recordedRequests()
        let components = URLComponents(url: seen[0].url!, resolvingAgainstBaseURL: false)!
        #expect(components.queryItems?.contains(where: { $0.name == "key" }) == false)
        #expect(components.queryItems?.contains(where: { $0.name == "langRestrict" }) == false)
    }

    @Test func mapsQuotaErrorFromHTTPResponse() async throws {
        let errorBody = try FixtureLoader.data("error_quota")
        let session = URLSession.stubbed { _ in .init(statusCode: 403, data: errorBody) }
        let client = makeClient(session: session, apiKey: nil)
        await #expect(throws: DomainError.catalogQuotaExceeded) {
            _ = try await client.volumes(query: "x", startIndex: 0, maxResults: 20, langRestrict: nil)
        }
    }

    @Test func mapsOfflineAsNetworkError() async throws {
        let session = URLSession.stubbed { _ in throw URLError(.notConnectedToInternet) }
        let client = makeClient(session: session, apiKey: nil)
        await #expect(throws: DomainError.network) {
            _ = try await client.volumes(query: "x", startIndex: 0, maxResults: 20, langRestrict: nil)
        }
    }

    @Test func retriesOn429_thenSucceeds() async throws {
        let okBody = try FixtureLoader.data("volumes_empty")
        let counter = Counter()
        let session = URLSession.stubbed { _ in
            let n = counter.incrementAndGet()
            if n == 1 { return .init(statusCode: 429, data: Data()) }
            return .init(statusCode: 200, data: okBody)
        }
        let client = GoogleBooksClient(
            session: session,
            apiKeyProvider: { nil },
            bundleID: "com.example.app",
            retryDelays: [1, 1],
            sleep: { _ in }
        )
        _ = try await client.volumes(query: "x", startIndex: 0, maxResults: 20, langRestrict: nil)
        #expect(counter.value == 2)
    }

    @Test func givesUpAfterRetriesOn500() async throws {
        let counter = Counter()
        let session = URLSession.stubbed { _ in
            counter.incrementAndGet()
            return .init(statusCode: 500, data: Data())
        }
        let client = GoogleBooksClient(
            session: session,
            apiKeyProvider: { nil },
            bundleID: "com.example.app",
            retryDelays: [1, 1],
            sleep: { _ in }
        )
        await #expect(throws: DomainError.self) {
            _ = try await client.volumes(query: "x", startIndex: 0, maxResults: 20, langRestrict: nil)
        }
        #expect(counter.value == 3)
    }
}

/// Swift Testing から参照できるスレッドセーフなカウンタ。
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return _value }
    func incrementAndGet() -> Int {
        lock.lock(); defer { lock.unlock() }
        _value += 1
        return _value
    }
}
