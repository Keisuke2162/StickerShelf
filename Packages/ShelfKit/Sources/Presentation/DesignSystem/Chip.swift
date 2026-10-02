#if canImport(UIKit)
import SwiftUI

public struct Chip: View {
    public let title: String
    public let isSelected: Bool
    public let action: () -> Void

    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(FontToken.label())
                .foregroundStyle(isSelected ? Color.white : ColorToken.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? ColorToken.ink : ColorToken.surface)
                )
                .overlay(
                    Capsule().stroke(ColorToken.hairline, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

#endif
