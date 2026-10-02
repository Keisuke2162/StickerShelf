#if canImport(UIKit)
import SwiftUI
import Domain

/// `CoverImage` に応じて書影を描画する非同期ロード view。
/// 画像が無い本は `GeneratedCoverView` にフォールバックする。
public struct CoverImageView: View {
    public let cover: CoverImage
    public let title: String
    public let loader: @Sendable (CoverImage) async -> Data?

    @State private var imageData: Data?

    public init(cover: CoverImage, title: String, loader: @escaping @Sendable (CoverImage) async -> Data?) {
        self.cover = cover
        self.title = title
        self.loader = loader
    }

    public var body: some View {
        Group {
            if let data = imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                GeneratedCoverView(title: title)
            }
        }
        .task(id: coverKey) {
            imageData = await loader(cover)
        }
    }

    private var coverKey: String {
        switch cover {
        case .remote(let url): return "remote:\(url.absoluteString)"
        case .local(let name): return "local:\(name)"
        case .none: return "none"
        }
    }
}

#endif
