import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("GoogleBooksCatalogRepository", .serialized)
struct GoogleBooksCatalogRepositoryTests {
    private func makeClient(session: URLSession) -> GoogleBooksClient {
        GoogleBooksClient(
            session: session,
            apiKeyProvider: { nil },
            bundleID: "com.example.app",
            retryDelays: [],
            sleep: { _ in }
        )
    }

    @Test func search_addsLangJaWhenRestricted_andStartIndexPage1() async throws {
        let data = try FixtureLoader.data("volumes_empty")
        let session = URLSession.stubbed { _ in .init(statusCode: 200, data: data) }
        let prefs = UserDefaultsSearchPreferenceRepository(defaults: UserDefaults(suiteName: "cat-\(UUID().uuidString)")!)
        prefs.setRestrictToJapanese(true)
        let repo = GoogleBooksCatalogRepository(client: makeClient(session: session), preferences: prefs)
        _ = try await repo.search(keyword: "宇宙", page: 1)
        let seen = StubURLProtocol.recordedRequests()
        let components = URLComponents(url: seen[0].url!, resolvingAgainstBaseURL: false)!
        #expect(components.queryItems?.contains(where: { $0.name == "langRestrict" && $0.value == "ja" }) == true)
        #expect(components.queryItems?.contains(where: { $0.name == "startIndex" && $0.value == "20" }) == true)
    }

    @Test func search_omitsLangWhenNotRestricted() async throws {
        let data = try FixtureLoader.data("volumes_empty")
        let session = URLSession.stubbed { _ in .init(statusCode: 200, data: data) }
        let prefs = UserDefaultsSearchPreferenceRepository(defaults: UserDefaults(suiteName: "cat-\(UUID().uuidString)")!)
        prefs.setRestrictToJapanese(false)
        let repo = GoogleBooksCatalogRepository(client: makeClient(session: session), preferences: prefs)
        _ = try await repo.search(keyword: "foo", page: 0)
        let seen = StubURLProtocol.recordedRequests()
        let components = URLComponents(url: seen[0].url!, resolvingAgainstBaseURL: false)!
        #expect(components.queryItems?.contains(where: { $0.name == "langRestrict" }) == false)
    }

    @Test func findByISBN_fallsBackToISBN10WhenEmpty() async throws {
        let emptyData = try FixtureLoader.data("volumes_empty")
        let hitData = try FixtureLoader.data("volumes_isbn10_only")
        let counter = Counter()
        let session = URLSession.stubbed { req in
            let n = counter.incrementAndGet()
            let url = req.url!.absoluteString
            // 1 回目は ISBN-13 で問い合わせ → 0 件
            if n == 1 {
                #expect(url.contains("isbn:9784101010014"))
                return .init(statusCode: 200, data: emptyData)
            }
            // 2 回目は ISBN-10 で問い合わせ → 1 件
            #expect(url.contains("isbn:4101010013"))
            return .init(statusCode: 200, data: hitData)
        }
        let prefs = UserDefaultsSearchPreferenceRepository(defaults: UserDefaults(suiteName: "cat-\(UUID().uuidString)")!)
        let repo = GoogleBooksCatalogRepository(client: makeClient(session: session), preferences: prefs)
        let book = try await repo.find(isbn: ISBN("9784101010014")!)
        #expect(book != nil)
        #expect(counter.value == 2)
    }

    @Test func findByISBN_doesNotHitLangRestrict() async throws {
        let data = try FixtureLoader.data("volumes_isbn10_only")
        let session = URLSession.stubbed { _ in .init(statusCode: 200, data: data) }
        let prefs = UserDefaultsSearchPreferenceRepository(defaults: UserDefaults(suiteName: "cat-\(UUID().uuidString)")!)
        prefs.setRestrictToJapanese(true)
        let repo = GoogleBooksCatalogRepository(client: makeClient(session: session), preferences: prefs)
        _ = try await repo.find(isbn: ISBN("9784101010014")!)
        let seen = StubURLProtocol.recordedRequests()
        let components = URLComponents(url: seen[0].url!, resolvingAgainstBaseURL: false)!
        #expect(components.queryItems?.contains(where: { $0.name == "langRestrict" }) == false)
    }
}
