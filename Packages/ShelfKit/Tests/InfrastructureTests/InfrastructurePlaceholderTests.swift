import Testing
@testable import Infrastructure

@Suite("Infrastructure モジュール疎通")
struct InfrastructurePlaceholderTests {
    @Test func moduleName() {
        #expect(ShelfKitInfrastructure.moduleName == "Infrastructure")
    }
}
