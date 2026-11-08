#if canImport(UIKit)
import Foundation
import SwiftUI
import Observation
import Domain

/// アプリ全体のテーマカラー（背景色）を保持・観測可能にする @Observable ストア。
/// RootView で `.environment(theme)` 経由で全画面に注入される。
@MainActor
@Observable
public final class ThemeStore {
    public private(set) var color: BoardColor
    private let repository: ThemePreferenceRepository

    public init(repository: ThemePreferenceRepository) {
        self.repository = repository
        self.color = repository.themeColor()
    }

    public func set(_ color: BoardColor) {
        self.color = color
        repository.setThemeColor(color)
    }

    /// アプリ共通の背景色（SwiftUI の Color）。
    public var backgroundColor: Color {
        BoardAppearanceStyle.background(color)
    }
}

#endif
