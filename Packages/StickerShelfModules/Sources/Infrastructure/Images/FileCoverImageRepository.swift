import Foundation
import CryptoKit
import Domain

public actor FileCoverImageRepository: CoverImageRepository {
    public enum ImageError: Error, Sendable {
        case directoryUnavailable
        case missing
    }

    private let fileManager: FileManager
    private let userDirectory: URL
    private let remoteCacheDirectory: URL
    private let session: URLSession
    private let memoryCache = NSCache<NSString, NSData>()
    private var inFlight: [URL: Task<Data?, Error>] = [:]

    public init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        userDirectory: URL? = nil,
        remoteCacheDirectory: URL? = nil
    ) throws {
        self.fileManager = fileManager
        self.session = session

        let appSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let caches = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let user = userDirectory ?? appSupport.appendingPathComponent("Covers", isDirectory: true)
        let remote = remoteCacheDirectory ?? caches.appendingPathComponent("RemoteCovers", isDirectory: true)
        try fileManager.createDirectory(at: user, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: remote, withIntermediateDirectories: true)
        self.userDirectory = user
        self.remoteCacheDirectory = remote
        memoryCache.countLimit = 256
    }

    public func imageData(for cover: CoverImage) async throws -> Data? {
        switch cover {
        case .none:
            return nil
        case .local(let name):
            let url = userDirectory.appendingPathComponent(name)
            return readOrLoad(url: url)
        case .remote(let url):
            if let cached = cachedRemote(url: url) { return cached }
            return try await downloadRemote(url: url)
        }
    }

    public func saveUserImage(_ data: Data) async throws -> CoverImage {
        let name = "\(UUID().uuidString).jpg"
        let url = userDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        memoryCache.setObject(data as NSData, forKey: url.path as NSString)
        return .local(fileName: name)
    }

    public func deleteLocal(_ cover: CoverImage) async throws {
        guard case .local(let name) = cover else { return }
        let url = userDirectory.appendingPathComponent(name)
        try? fileManager.removeItem(at: url)
        memoryCache.removeObject(forKey: url.path as NSString)
    }

    // MARK: - Private

    private func readOrLoad(url: URL) -> Data? {
        if let cached = memoryCache.object(forKey: url.path as NSString) {
            return cached as Data
        }
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        memoryCache.setObject(data as NSData, forKey: url.path as NSString)
        return data
    }

    private func cachedRemote(url: URL) -> Data? {
        let path = remoteCacheURL(for: url)
        return readOrLoad(url: path)
    }

    private func downloadRemote(url: URL) async throws -> Data? {
        if let existing = inFlight[url] {
            return try await existing.value
        }
        let path = remoteCacheURL(for: url)
        let session = self.session
        let task = Task<Data?, Error> {
            do {
                var request = URLRequest(url: url)
                request.setValue("StickerShelf", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    return nil
                }
                try? data.write(to: path, options: .atomic)
                return data
            } catch is CancellationError {
                return nil
            }
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let data = try await task.value
        if let data {
            memoryCache.setObject(data as NSData, forKey: path.path as NSString)
        }
        return data
    }

    private func remoteCacheURL(for url: URL) -> URL {
        let hashed = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return remoteCacheDirectory.appendingPathComponent("\(hashed).img")
    }
}
