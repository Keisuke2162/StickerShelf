public struct ReadingProgress: Hashable, Sendable, Codable {
    public let currentPage: Int

    public init(currentPage: Int = 0) {
        self.currentPage = max(0, currentPage)
    }

    public func ratio(pageCount: Int?) -> Double? {
        guard let total = pageCount, total > 0 else { return nil }
        return min(1.0, Double(currentPage) / Double(total))
    }
}
