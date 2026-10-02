#if canImport(UIKit)
import SwiftUI

public struct SegmentedSwitch<Value: Hashable>: View {
    public struct Option: Identifiable {
        public let id: Value
        public let title: String
        public let badge: Int?

        public init(id: Value, title: String, badge: Int? = nil) {
            self.id = id
            self.title = title
            self.badge = badge
        }
    }

    public let options: [Option]
    @Binding public var selection: Value

    public init(options: [Option], selection: Binding<Value>) {
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button {
                    selection = option.id
                } label: {
                    HStack(spacing: 6) {
                        Text(option.title)
                            .font(FontToken.sectionTitle())
                            .foregroundStyle(selection == option.id ? ColorToken.ink : ColorToken.inkSecondary)
                        if let badge = option.badge {
                            Text("\(badge)")
                                .font(FontToken.caption().weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(ColorToken.accent))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selection == option.id ? ColorToken.surface : .clear)
                            .shadow(color: selection == option.id ? ColorToken.ink.opacity(0.08) : .clear, radius: 4, y: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16).fill(ColorToken.segmentTrack))
    }
}

#endif
