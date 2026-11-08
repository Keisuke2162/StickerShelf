import Foundation

/// アプリ全体のテーマカラー（背景色）の設定を永続化する。
/// 値 enum は `BoardColor` を兼用する（ボード背景色と同じパレット）。
public protocol ThemePreferenceRepository: Sendable {
    func themeColor() -> BoardColor
    func setThemeColor(_ color: BoardColor)
}
