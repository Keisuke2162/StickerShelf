import Foundation
import Domain

public final class UserDefaultsSearchPreferenceRepository: SearchPreferenceRepository, @unchecked Sendable {
    public let defaults: UserDefaults
    private let key = "search.restrictToJapanese"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: key) == nil {
            defaults.set(true, forKey: key)
        }
    }

    public func restrictToJapanese() -> Bool {
        defaults.bool(forKey: key)
    }

    public func setRestrictToJapanese(_ value: Bool) {
        defaults.set(value, forKey: key)
    }
}
