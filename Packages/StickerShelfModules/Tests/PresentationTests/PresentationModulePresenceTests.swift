#if canImport(UIKit)
import Testing
@testable import Presentation
import Domain

@Suite("Presentation モジュール疎通")
struct PresentationModulePresenceTests {
    @Test func startupOptionsParsing() {
        let options = StartupOptions.parse(from: ["app", "-SeedSampleData", "YES", "-StartScreen", "shelf"])
        #expect(options.seedSampleData)
        #expect(options.startScreen == .shelf)
    }
}
#endif
