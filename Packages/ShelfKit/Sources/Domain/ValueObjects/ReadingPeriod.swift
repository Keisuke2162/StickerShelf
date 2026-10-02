import Foundation

public struct ReadingPeriod: Hashable, Sendable, Codable {
    public var startedAt: Date?
    public var finishedAt: Date?

    public init(startedAt: Date? = nil, finishedAt: Date? = nil) {
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    /// `finishedAt >= startedAt` を日単位で検証する。
    public func isValid(calendar: Calendar = .current) -> Bool {
        guard let start = startedAt, let finish = finishedAt else { return true }
        let s = calendar.startOfDay(for: start)
        let f = calendar.startOfDay(for: finish)
        return f >= s
    }
}
