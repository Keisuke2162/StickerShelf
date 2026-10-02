#if canImport(UIKit)
import SwiftUI
import Domain

public struct StickerView: View {
    public let cover: CoverImage
    public let title: String
    public let edge: StickerEdge
    public let size: CGSize
    public let loader: @Sendable (CoverImage) async -> Data?

    public init(cover: CoverImage, title: String, edge: StickerEdge, size: CGSize, loader: @escaping @Sendable (CoverImage) async -> Data?) {
        self.cover = cover
        self.title = title
        self.edge = edge
        self.size = size
        self.loader = loader
    }

    public var body: some View {
        ZStack {
            switch edge {
            case .white:
                CoverImageView(cover: cover, title: title, loader: loader)
                    .frame(width: size.width - 8, height: size.height - 8)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(4)
                    .background(ColorToken.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            case .none:
                CoverImageView(cover: cover, title: title, loader: loader)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            case .holo:
                ZStack {
                    CoverImageView(cover: cover, title: title, loader: loader)
                        .frame(width: size.width - 8, height: size.height - 8)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(4)
                        .background(ColorToken.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: 0xFF4444), Color(hex: 0xFFC842),
                            Color(hex: 0x3BE88B), Color(hex: 0x3BC8FF),
                            Color(hex: 0xB84EF0), Color(hex: 0xFF4444),
                        ]),
                        center: .center
                    )
                    .opacity(0.35)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: ColorToken.ink.opacity(0.16), radius: 7, y: 8)
        .shadow(color: .black.opacity(0.05), radius: 0, y: 1)
        .accessibilityLabel(title)
    }
}

#endif
