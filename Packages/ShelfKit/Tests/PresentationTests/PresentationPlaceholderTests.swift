import Testing
@testable import Presentation

@Suite("Presentation モジュール疎通")
struct PresentationPlaceholderTests {
    @Test func moduleName() {
        #expect(ShelfKitPresentation.moduleName == "Presentation")
    }
}
