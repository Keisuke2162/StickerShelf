#if canImport(UIKit)
import SwiftUI

public struct GeneratedCoverView: View {
    public let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        GeometryReader { geo in
            let color = Self.palette[abs(title.hashValue) % Self.palette.count]
            ZStack(alignment: .bottomLeading) {
                color
                Text(title)
                    .font(FontToken.caption().weight(.bold))
                    .foregroundStyle(Self.textColor(on: color))
                    .lineLimit(3)
                    .padding(6)
                    .frame(maxWidth: geo.size.width * 0.9, alignment: .leading)
            }
        }
    }

    public static let palette: [Color] = [
        Color(hex: 0x24305E), Color(hex: 0x2A7F7A), Color(hex: 0x6B4A3A),
        Color(hex: 0x4E7A3A), Color(hex: 0x1B1D22), Color(hex: 0xC8442F),
        Color(hex: 0x8DA9C4), Color(hex: 0x3E5C86), Color(hex: 0xD9A33A),
        Color(hex: 0xE8B9A1), Color(hex: 0x7A3B69), Color(hex: 0x5E8C61),
        Color(hex: 0x1F4E5F), Color(hex: 0xB7C4CF), Color(hex: 0xE07A3F),
        Color(hex: 0x3B3B58), Color(hex: 0xF2C14E), Color(hex: 0xA0522D),
    ]

    /// 背景の相対明度に応じて白か ink を選ぶ。
    static func textColor(on color: Color) -> Color {
        let components = color.rgbComponents()
        let luminance = 0.2126 * components.r + 0.7152 * components.g + 0.0722 * components.b
        return luminance > 0.6 ? ColorToken.ink : .white
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    func rgbComponents() -> (r: Double, g: Double, b: Double) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
        #else
        return (0, 0, 0)
        #endif
    }
}

#endif
