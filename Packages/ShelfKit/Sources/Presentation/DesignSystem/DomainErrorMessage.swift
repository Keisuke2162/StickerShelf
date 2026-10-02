#if canImport(UIKit)
import Foundation
import Domain

/// Domain エラーをユーザー向けの日本語文言に変換する Presentation ユーティリティ。
public enum DomainErrorMessage {
    public static func describe(_ error: Error) -> String {
        if let domain = error as? DomainError {
            switch domain {
            case .invalidTitle: return "タイトルを入力してください。"
            case .invalidISBN: return "ISBN の形式が正しくありません。"
            case .invalidPeriod: return "読了日は読み始めた日より後にしてください。"
            case .pageOutOfRange: return "現在ページは 0 以上、総ページ数以下にしてください。"
            case .stickerNotAllowedForUnread: return "積読の本にはステッカーを配置できません。"
            case .duplicateBook: return "この本は既に登録されています。"
            case .bookNotFound: return "対象の本が見つかりませんでした。"
            case .catalogUnavailable: return "検索サービスに接続できません。時間をおいて再度お試しください。"
            case .catalogQuotaExceeded: return "検索の上限に達しました。設定で API キーを登録すると安定します。"
            case .invalidAPIKey: return "API キーが正しくありません。設定を確認してください。"
            case .network: return "インターネットに接続されていません。"
            }
        }
        return error.localizedDescription
    }
}

#endif
