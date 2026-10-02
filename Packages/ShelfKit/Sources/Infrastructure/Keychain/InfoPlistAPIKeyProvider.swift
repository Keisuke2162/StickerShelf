import Foundation
import Domain

/// Info.plist 経由で Secrets.xcconfig から埋め込まれた API キーを読む。
/// Keychain にキーが保存されていないときのフォールバックとして使う。
public struct InfoPlistAPIKeyProvider: Sendable {
    public let bundle: Bundle
    public let infoKey: String

    public init(bundle: Bundle = .main, infoKey: String = "GoogleBooksAPIKey") {
        self.bundle = bundle
        self.infoKey = infoKey
    }

    public func load() -> APIKey? {
        guard let raw = bundle.object(forInfoDictionaryKey: infoKey) as? String else { return nil }
        return APIKey(raw)
    }
}
