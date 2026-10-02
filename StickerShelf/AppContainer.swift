import Foundation

/// Composition Root。Phase 2 以降で具象リポジトリ・UseCase・ViewModel を生成する。
public struct AppContainer: Sendable {
    public static func makeDefault() -> AppContainer {
        AppContainer()
    }
}
