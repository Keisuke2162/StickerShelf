import Foundation

/// 本屋などで気になった本のタイトルを連続メモするための軽量エントリ。
/// タイトル文字列と作成日時のみを持ち、書籍情報とは独立に蓄積される。
public struct TitleMemo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let createdAt: Date

    public init(id: UUID = UUID(), title: String, createdAt: Date) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.invalidTitle }
        self.id = id
        self.title = trimmed
        self.createdAt = createdAt
    }

    /// 永続層からの再構築用。信頼済みデータ前提で検証をスキップする。
    public static func reconstruct(id: UUID, title: String, createdAt: Date) -> TitleMemo {
        TitleMemo(reconstructing: id, title: title, createdAt: createdAt)
    }

    private init(reconstructing id: UUID, title: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
