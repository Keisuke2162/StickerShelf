import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("GoogleBooksClient", .serialized)
struct GoogleBooksClientTests {
    @Test func includesBundleHeader_andAttachesKey_whenPresent() async throws {
        let fixture = try FixtureLoader.data("volumes_search_normal")
        let session = URLSession.stubbed { _ in .init(statusCode: 200, data: fixture) }
        let client = GoogleBooksClient(
            session: session,
            apiKeyProvider: { APIKey("test-key-1234") },
            bundleID: "com.example.app"
        )
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
        let client = GoogleBooksClient(
            session: session,
            apiKeyProvider: { nil },
            bundleID: "com.example.app"
        )
        _ = try await client.volumes(query: "foo", startIndex: 0, maxResults: 20, langRestrict: nil)
        let seen = StubURLProtocol.recordedRequests()
        let components = URLComponents(url: seen[0].url!, resolvingAgainstBaseURL: false)!
        #expect(components.queryItems?.contains(where: { $0.name == "key" }) == false)
        #expect(components.queryItems?.contains(where: { $0.name == "langRestrict" }) == false)
    }

    @Test func mapsQuotaErrorFromHTTPResponse() async throws {
        let errorBody = try FixtureLoader.data("error_quota")
        let session = URLSession.stubbed { _ in .init(statusCode: 403, data: errorBody) }
        let client = GoogleBooksClient(
            session: session,
            apiKeyProvider: { nil },
            bundleID: "com.example.app"
        )
        await #expect(throws: DomainError.catalogQuotaExceeded) {
            _ = try await client.volumes(query: "x", startIndex: 0, maxResults: 20, langRestrict: nil)
        }
    }

    @Test func mapsOfflineAsNetworkError() async throws {
        let session = URLSession.stubbed { _ in throw URLError(.notConnectedToInternet) }
        let client = GoogleBooksClient(
            session: session,
            apiKeyProvider: { nil },
            bundleID: "com.example.app"
        )
        await #expect(throws: DomainError.network) {
            _ = try await client.volumes(query: "x", startIndex: 0, maxResults: 20, langRestrict: nil)
        }
    }
}
