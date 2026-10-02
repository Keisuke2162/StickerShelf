import Testing
@testable import Domain

@Suite("Domain モジュール疎通")
struct DomainPlaceholderTests {
    @Test func moduleNameIsDomain() {
        #expect(ShelfKitDomain.moduleName == "Domain")
    }
}
