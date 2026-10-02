import Foundation

public struct APIKey: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.rawValue = trimmed
    }

    /// ログや UI 表示用のマスク済み文字列。
    public var description: String {
        guard rawValue.count > 4 else { return "••••" }
        let prefix = rawValue.prefix(4)
        let suffix = rawValue.suffix(4)
        return "\(prefix)••••\(suffix)"
    }
}
