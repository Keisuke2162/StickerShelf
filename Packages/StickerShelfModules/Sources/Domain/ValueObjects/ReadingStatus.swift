public enum ReadingStatus: String, Sendable, Codable, CaseIterable {
    case unread
    case reading
    case finished

    public var isOnShelf: Bool {
        self == .reading || self == .finished
    }
}
