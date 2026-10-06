#if canImport(UIKit)
import SwiftUI

public struct Chip: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void
    public let onLongPress: (() -> Void)?

    public init(title: String, isSelected: Bool, action: @escaping () -> Void, onLongPress: (() -> Void)? = nil) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.onLongPress = onLongPress
    }

    public var body: some View {
        let shape = Capsule()
        return Text(title)
            .font(FontToken.label())
            .foregroundStyle(isSelected ? Color.white : ColorToken.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .frame(minHeight: 32)
            .background(shape.fill(isSelected ? ColorToken.ink : ColorToken.surface))
            .overlay(shape.stroke(ColorToken.hairline, lineWidth: isSelected ? 0 : 1))
            .contentShape(shape)
            // Button をやめて素の View + 手動ジェスチャにしているのは、Chip 自身で長押しアクションを
            // 受けたいケース（本棚ボードチップの編集起動）で、Button にかぶせた onLongPressGesture が
            // タップに食われて発火しない SwiftUI の挙動を回避するため。
            .onTapGesture { action() }
            .modifier(ChipLongPressModifier(onLongPress: onLongPress))
    }
}

private struct ChipLongPressModifier: ViewModifier {
    let onLongPress: (() -> Void)?

    func body(content: Content) -> some View {
        if let onLongPress {
            content.onLongPressGesture(minimumDuration: 0.4) { onLongPress() }
        } else {
            content
        }
    }
}

#endif
