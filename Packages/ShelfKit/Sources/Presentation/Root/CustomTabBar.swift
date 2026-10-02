#if canImport(UIKit)
import SwiftUI

struct CustomTabBar: View {
    let router: Router

    var body: some View {
        ZStack {
            Rectangle()
                .fill(ColorToken.surface)
                .frame(height: 84)
                .overlay(
                    Rectangle().fill(ColorToken.hairline).frame(height: 1),
                    alignment: .top
                )
                .shadow(color: ColorToken.ink.opacity(0.04), radius: 8, y: -2)

            HStack(spacing: 0) {
                tabButton(title: "ボード", icon: "square.on.square", tab: .board)
                tabButton(title: "カレンダー", icon: "calendar", tab: .calendar)
                Color.clear.frame(maxWidth: .infinity)
                tabButton(title: "設定", icon: "gearshape", tab: .settings)
            }
            .padding(.horizontal, 16)
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
    }

    private func tabButton(title: String, icon: String, tab: Router.Tab) -> some View {
        let selected = router.selectedTab == tab
        return Button {
            router.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: selected ? .bold : .regular))
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
