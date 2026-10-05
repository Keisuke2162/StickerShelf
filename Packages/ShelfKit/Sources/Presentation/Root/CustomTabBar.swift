#if canImport(UIKit)
import SwiftUI

struct CustomTabBar: View {
    let router: Router

    var body: some View {
        HStack(spacing: 0) {
            tabButton(title: "本棚", icon: "square.on.square", tab: .shelf)
            tabButton(title: "積読", icon: "square.stack.3d.down.right", tab: .pile)
            bookActionButton
            tabButton(title: "カレンダー", icon: "calendar", tab: .calendar)
            tabButton(title: "マイページ", icon: "person.circle", tab: .settings)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .frame(height: 84)
        // 背景を 1 枚にまとめて Safe Area 下部まで拡張。
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

    /// 「本」タブ。選択状態は持たず、タップで本を追加画面を開く。
    private var bookActionButton: some View {
        Button {
            router.isAddingBook = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 20, weight: .bold))
                Text("本")
                    .font(FontToken.tabLabel(selected: false))
            }
            .foregroundStyle(ColorToken.accent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("本を追加")
    }
}

#endif
