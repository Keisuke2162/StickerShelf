import Foundation
import Domain

public final class UserDefaultsThemePreferenceRepository: ThemePreferenceRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "themeColor"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func themeColor() -> BoardColor {
        guard let raw = defaults.string(forKey: key),
              let color = BoardColor(rawValue: raw) else {
            return .cream
        }
        return color
    }

    public func setThemeColor(_ color: BoardColor) {
        defaults.set(color.rawValue, forKey: key)
    }
}
