import Testing
@testable import Domain

@Suite("APIKey")
struct APIKeyTests {
    @Test func rejectsEmpty() {
        #expect(APIKey("") == nil)
        #expect(APIKey("   ") == nil)
    }

    @Test func acceptsAndMasks() {
        let key = APIKey("AIzaSyExampleKey1234")
        #expect(key != nil)
        #expect(key?.description.contains("AIza") == true)
        #expect(key?.description.contains("1234") == true)
        #expect(key?.description.contains("Example") == false)
    }

    @Test func shortKeyFullyMasked() {
        let key = APIKey("abcd")
        #expect(key?.description == "••••")
    }
}
