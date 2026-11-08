#if canImport(UIKit)
import SwiftUI

/// デザイン仕様のタイポグラフィトークン。
/// Dela Gothic One / Zen Kaku Gothic New が同梱されていない場合は Font.system にフォールバックする。
public enum FontToken {
    public static func screenTitle() -> Font { heading(size: 26) }
    public static func statNumber() -> Font { heading(size: 20) }
    public static func bookTitleLarge() -> Font { body(size: 20, weight: .bold) }
    public static func sectionTitle() -> Font { body(size: 15, weight: .bold) }
    public static func bodyRegular(size: CGFloat = 15) -> Font { body(size: size, weight: .regular) }
    public static func label() -> Font { body(size: 12, weight: .bold) }
    public static func caption() -> Font { body(size: 11, weight: .regular) }
    public static func tabLabel(selected: Bool) -> Font { body(size: 10, weight: selected ? .bold : .regular) }

    private static func heading(size: CGFloat) -> Font {
        if UIFont(name: "DelaGothicOne-Regular", size: size) != nil {
            return Font.custom("DelaGothicOne-Regular", size: size, relativeTo: .title)
        }
        return .system(size: size, weight: .black, design: .rounded)
    }

    private static func body(size: CGFloat, weight: Font.Weight) -> Font {
        let name: String
        switch weight {
        case .bold:
            name = "ZenKakuGothicNew-Bold"
        case .medium:
            name = "ZenKakuGothicNew-Medium"
        default:
            name = "ZenKakuGothicNew-Regular"
        }
        if UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size, relativeTo: .body)
        }
        return .system(size: size, weight: weight)
    }
}

#endif
