import Foundation

public enum CoverImage: Hashable, Sendable, Codable {
    case remote(URL)
    case local(fileName: String)
    case none

    public var isLocal: Bool {
        if case .local = self { return true }
        return false
    }
}
