import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("KeychainAPIKeyRepository")
struct KeychainAPIKeyRepositoryTests {
    private func makeRepo(fallback: (@Sendable () -> APIKey?)? = nil) -> KeychainAPIKeyRepository {
        KeychainAPIKeyRepository(service: "StickerShelfTest-\(UUID().uuidString)", fallback: fallback)
    }

    @Test func returnsFallbackWhenKeychainEmpty() throws {
        let repo = makeRepo(fallback: { APIKey("fallback-key-1234") })
        let loaded = try repo.load()
        #expect(loaded?.rawValue == "fallback-key-1234")
    }

    @Test func returnsNilWhenNoFallbackAndEmpty() throws {
        let repo = makeRepo()
        #expect(try repo.load() == nil)
    }

    @Test func saveLoadDeleteRoundTrip() throws {
        let repo = makeRepo(fallback: { APIKey("fallback") })
        let saved = APIKey("real-key-abcd")!
        try repo.save(saved)
        let loaded = try repo.load()
        #expect(loaded?.rawValue == "real-key-abcd")
        try repo.delete()
        let afterDelete = try repo.load()
        #expect(afterDelete?.rawValue == "fallback")
    }

    @Test func saveOverwritesExistingValue() throws {
        let repo = makeRepo()
        try repo.save(APIKey("first")!)
        try repo.save(APIKey("second")!)
        #expect(try repo.load()?.rawValue == "second")
        try repo.delete()
    }
}
