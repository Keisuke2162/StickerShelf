import Testing
@testable import Application
@testable import Domain

@Suite("APIKey UseCases")
struct APIKeyUseCasesTests {
    @Test func saveLoadDelete() throws {
        let repo = InMemoryAPIKeyRepository()
        let save = SaveAPIKeyUseCase(repository: repo)
        let load = LoadAPIKeyStatusUseCase(repository: repo)
        let del = DeleteAPIKeyUseCase(repository: repo)

        #expect(try load.execute() == .notSet)
        try save.execute(APIKey("abcd1234efgh")!)
        if case .set(let masked) = try load.execute() {
            #expect(masked.contains("abcd"))
            #expect(masked.contains("efgh"))
            #expect(!masked.contains("1234"))
        } else {
            Issue.record("expected .set, got .notSet")
        }
        try del.execute()
        #expect(try load.execute() == .notSet)
    }
}
