#if canImport(UIKit)
import Foundation
import Observation
import Domain

/// 積読の「すべて」用（＝実 Board を持たない仮想フォルダ）の見た目設定を保持・観測可能にする。
/// 永続化は UserDefaults。
@MainActor
@Observable
public final class PileAllFolderAppearanceStore {
    public private(set) var appearance: BoardAppearance
    private let defaults: UserDefaults
    private let key = "pileAllFolderAppearance"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(BoardAppearance.self, from: data) {
            self.appearance = decoded
        } else {
            self.appearance = .default
        }
    }

    public func set(_ appearance: BoardAppearance) {
        self.appearance = appearance
        if let data = try? JSONEncoder().encode(appearance) {
            defaults.set(data, forKey: key)
        }
    }
}

#endif
