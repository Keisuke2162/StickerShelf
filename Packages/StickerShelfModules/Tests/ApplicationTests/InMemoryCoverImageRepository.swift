import Foundation
import Domain

public actor InMemoryCoverImageRepository: CoverImageRepository {
    private var localImages: [String: Data] = [:]
    public var remoteImages: [URL: Data] = [:]
    public private(set) var deletedLocalFiles: [String] = []

    public init() {}

    public func imageData(for cover: CoverImage) async throws -> Data? {
        switch cover {
        case .none: return nil
        case .local(let name): return localImages[name]
        case .remote(let url): return remoteImages[url]
        }
    }

    public func saveUserImage(_ data: Data) async throws -> CoverImage {
        let name = "\(UUID().uuidString).jpg"
        localImages[name] = data
        return .local(fileName: name)
    }

    public func deleteLocal(_ cover: CoverImage) async throws {
        guard case .local(let name) = cover else { return }
        localImages.removeValue(forKey: name)
        deletedLocalFiles.append(name)
    }
}
