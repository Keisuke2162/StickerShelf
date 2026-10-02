import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("FileCoverImageRepository")
struct FileCoverImageRepositoryTests {
    private func makeRepo() throws -> FileCoverImageRepository {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("tests-\(UUID().uuidString)", isDirectory: true)
        let user = base.appendingPathComponent("User", isDirectory: true)
        let remote = base.appendingPathComponent("Remote", isDirectory: true)
        return try FileCoverImageRepository(userDirectory: user, remoteCacheDirectory: remote)
    }

    @Test func saveAndLoadUserImage() async throws {
        let repo = try makeRepo()
        let payload = Data(repeating: 0xAB, count: 128)
        let cover = try await repo.saveUserImage(payload)
        guard case .local(let name) = cover else {
            Issue.record("expected local cover, got \(cover)")
            return
        }
        #expect(!name.isEmpty)
        let loaded = try await repo.imageData(for: cover)
        #expect(loaded == payload)
    }

    @Test func deleteLocalRemovesFile() async throws {
        let repo = try makeRepo()
        let cover = try await repo.saveUserImage(Data([0x01, 0x02, 0x03]))
        try await repo.deleteLocal(cover)
        let loaded = try await repo.imageData(for: cover)
        #expect(loaded == nil)
    }

    @Test func noneReturnsNil() async throws {
        let repo = try makeRepo()
        let data = try await repo.imageData(for: .none)
        #expect(data == nil)
    }
}
