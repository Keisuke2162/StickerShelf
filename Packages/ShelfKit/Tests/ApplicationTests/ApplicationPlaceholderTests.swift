import Testing
@testable import Application

@Suite("Application モジュール疎通")
struct ApplicationPlaceholderTests {
    @Test func moduleName() {
        #expect(ShelfKitApplication.moduleName == "Application")
    }
}
