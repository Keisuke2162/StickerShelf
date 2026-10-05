#if canImport(UIKit)
import SwiftUI

struct CustomTabBar: View {
    let router: Router

    var body: some View {
        ZStack {
            // 5 列均等グリッド: 本棚 / 積読 / (中央 ＋ スロット) / カレンダー / 設定
            HStack(spacing: 0) {
                tabButton(title: "本棚", icon: "square.on.square", tab: .shelf).frame(maxWidth: .infinity)
                tabButton(title: "積読", icon: "square.stack.3d.down.right", tab: .pile).frame(maxWidth: .infinity)
                Color.clear.frame(maxWidth: .infinity).frame(height: 44)
                tabButton(title: "カレンダー", icon: "calendar", tab: .calendar).frame(maxWidth: .infinity)
                tabButton(title: "設定", icon: "gearshape", tab: .settings).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            Button {
                router.isAddingBook = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(ColorToken.accent))
                    .overlay(Circle().stroke(.white, lineWidth: 4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("本を追加")
            .shadow(color: ColorToken.accent.opacity(0.35), radius: 9, y: 8)
            .offset(y: -26)
        }
        .frame(height: 84)
        // 背景を 1 枚にまとめて Safe Area 下部まで拡張。
        // 上端のヘアラインとシャドウは拡張範囲内で、下側は surface 一色のまま。
        .background {
            ColorToken.surface
                .overlay(Rectangle().fill(ColorToken.hairline).frame(height: 1), alignment: .top)
                .shadow(color: ColorToken.ink.opacity(0.04), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(title: String, icon: String, tab: Router.Tab) -> some View {
        let selected = router.selectedTab == tab
        return Button {
            router.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: selected ? .bold : .regular))
                Text(title)
                    .font(FontToken.tabLabel(selected: selected))
            }
            .foregroundStyle(selected ? ColorToken.ink : ColorToken.inkTertiary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}

#endif
