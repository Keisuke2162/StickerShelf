#if canImport(UIKit)
import SwiftUI

/// Asset Catalog（Bundle.module）に登録したカラートークンへのアクセサ。
public enum ColorToken {
    public static let boardBackground = named("boardBackground")
    public static let boardDot = named("boardDot")
    public static let pileBackground = named("pileBackground")
    public static let pileGrid = named("pileGrid")
    public static let pileFloor = named("pileFloor")
    public static let ink = named("ink")
    public static let inkSecondary = named("inkSecondary")
    public static let inkTertiary = named("inkTertiary")
    public static let surface = named("surface")
    public static let surfaceMuted = named("surfaceMuted")
    public static let segmentTrack = named("segmentTrack")
    public static let hairline = named("hairline")
    public static let accent = named("accent")
    public static let accentSoft = named("accentSoft")
    public static let sunday = named("sunday")
    public static let saturday = named("saturday")
    public static let tape = named("tape")

    private static func named(_ name: String) -> Color {
        Color(name, bundle: .module)
    }
}

#endif
