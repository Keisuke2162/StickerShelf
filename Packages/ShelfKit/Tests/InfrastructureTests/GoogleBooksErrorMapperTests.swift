import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("GoogleBooksErrorMapper")
struct GoogleBooksErrorMapperTests {
    @Test func mapsKeyInvalid400() throws {
        let data = try FixtureLoader.data("error_key_invalid")
        let error = GoogleBooksErrorMapper.map(statusCode: 400, data: data)
        #expect(error == .invalidAPIKey)
    }

    @Test func maps403Quota() throws {
        let data = try FixtureLoader.data("error_quota")
        let error = GoogleBooksErrorMapper.map(statusCode: 403, data: data)
        #expect(error == .catalogQuotaExceeded)
    }

    @Test func maps429() {
        let error = GoogleBooksErrorMapper.map(statusCode: 429, data: Data())
        #expect(error == .catalogQuotaExceeded)
    }

    @Test func maps503AsUnavailable() {
        let error = GoogleBooksErrorMapper.map(statusCode: 503, data: Data())
        if case .catalogUnavailable = error {} else {
            Issue.record("expected catalogUnavailable, got \(error)")
        }
    }

    @Test func mapsOfflineURLError() {
        let urlError = URLError(.notConnectedToInternet)
        #expect(GoogleBooksErrorMapper.map(urlError: urlError) == .network)
    }
}
