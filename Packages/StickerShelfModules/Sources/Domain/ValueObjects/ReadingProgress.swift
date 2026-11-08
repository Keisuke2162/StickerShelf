public struct ReadingProgress: Hashable, Sendable, Codable {
    public let currentPage: Int

    public init(currentPage: Int = 0) {
        self.currentPage = max(0, currentPage)
    }

    /// 0 未満のとき nil を返す失敗可能イニシャライザ。
    public init?(strict currentPage: Int) {
        guard currentPage >= 0 else { return nil }
        self.currentPage = currentPage
    }

    public func ratio(pageCount: Int?) -> Double? {
        guard let total = pageCount, total > 0 else { return nil }
        return min(1.0, Double(currentPage) / Double(total))
    }
}
