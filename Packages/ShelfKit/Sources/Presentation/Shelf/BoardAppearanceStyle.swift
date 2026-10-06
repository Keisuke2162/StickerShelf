#if canImport(UIKit)
import SwiftUI
import Domain

/// Domain の BoardColor / BoardPattern を SwiftUI の描画要素に変換するアダプタ。
/// Domain に SwiftUI 依存を持ち込まないため Presentation 側に置く。
enum BoardAppearanceStyle {
    static func background(_ color: BoardColor) -> Color {
        switch color {
        case .cream:    return Color(red: 1.00, green: 0.98, blue: 0.93)
        case .mint:     return Color(red: 0.90, green: 0.98, blue: 0.94)
        case .sky:      return Color(red: 0.90, green: 0.95, blue: 1.00)
        case .lavender: return Color(red: 0.94, green: 0.91, blue: 0.99)
        case .rose:     return Color(red: 1.00, green: 0.92, blue: 0.94)
        case .sand:     return Color(red: 0.98, green: 0.93, blue: 0.84)
        }
    }

    /// 書影やボード背景の線色（dot/grid/stripes 共通）。
    static func patternInk(_ color: BoardColor) -> Color {
        switch color {
        case .cream:    return Color(red: 0.65, green: 0.55, blue: 0.40).opacity(0.35)
        case .mint:     return Color(red: 0.35, green: 0.60, blue: 0.52).opacity(0.35)
        case .sky:      return Color(red: 0.35, green: 0.50, blue: 0.65).opacity(0.35)
        case .lavender: return Color(red: 0.55, green: 0.45, blue: 0.70).opacity(0.35)
        case .rose:     return Color(red: 0.70, green: 0.45, blue: 0.52).opacity(0.35)
        case .sand:     return Color(red: 0.65, green: 0.55, blue: 0.35).opacity(0.35)
        }
    }
}

/// 本棚ボードの背景（色 + 模様）。ShelfView の `board` 内で使う。
struct BoardBackgroundView: View {
    let appearance: BoardAppearance

    var body: some View {
        let base = BoardAppearanceStyle.background(appearance.color)
        let ink = BoardAppearanceStyle.patternInk(appearance.color)
        ZStack {
            base
            patternOverlay(ink: ink)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func patternOverlay(ink: Color) -> some View {
        switch appearance.pattern {
        case .plain:
            EmptyView()
        case .dots:
            Canvas { context, size in
                let spacing: CGFloat = 18
                for x in stride(from: spacing / 2, to: size.width, by: spacing) {
                    for y in stride(from: spacing / 2, to: size.height, by: spacing) {
                        let rect = CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)
                        context.fill(Path(ellipseIn: rect), with: .color(ink))
                    }
                }
            }
        case .grid:
            Canvas { context, size in
                let spacing: CGFloat = 24
                var path = Path()
                var x: CGFloat = spacing
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = spacing
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(path, with: .color(ink), lineWidth: 0.7)
            }
        case .stripes:
            Canvas { context, size in
                let spacing: CGFloat = 14
                var path = Path()
                let diag = size.width + size.height
                var offset: CGFloat = -size.height
                while offset < diag {
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                    offset += spacing
                }
                context.stroke(path, with: .color(ink), lineWidth: 0.8)
            }
        }
    }
}

#endif
