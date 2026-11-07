import Testing
import Foundation
@testable import Infrastructure

@Suite("UserDefaultsSearchPreferenceRepository")
struct UserDefaultsSearchPreferenceRepositoryTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func defaultsToTrueOnFirstUse() {
        let defaults = makeDefaults()
        let repo = UserDefaultsSearchPreferenceRepository(defaults: defaults)
        #expect(repo.restrictToJapanese() == true)
    }

    @Test func persistsExplicitFalse() {
        let defaults = makeDefaults()
        let repo = UserDefaultsSearchPreferenceRepository(defaults: defaults)
        repo.setRestrictToJapanese(false)
        #expect(repo.restrictToJapanese() == false)
        let repo2 = UserDefaultsSearchPreferenceRepository(defaults: defaults)
        #expect(repo2.restrictToJapanese() == false)
    }
}
