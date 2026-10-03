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
                // 書影本来の縦横比を維持して表示する（親の枠に対して fit）。
                // 画像の比と親フレームの比が異なる場合は、親の背景（白フチ or 空）が余白として見える。
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 生成カバー（画像なし）は枠を埋めて成立するデザイン前提なので、ここだけ従来通り埋める。
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
