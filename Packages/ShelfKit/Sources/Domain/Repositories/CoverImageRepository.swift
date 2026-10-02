import Foundation

public protocol CoverImageRepository: Sendable {
    func imageData(for cover: CoverImage) async throws -> Data?
    func saveUserImage(_ data: Data) async throws -> CoverImage
    func deleteLocal(_ cover: CoverImage) async throws
}
