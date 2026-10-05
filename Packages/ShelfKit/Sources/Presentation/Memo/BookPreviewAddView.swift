#if canImport(UIKit)
import SwiftUI
import Domain
import Application

/// 検索結果からタップされた 1 冊の書籍詳細 + 本棚/積読に追加するフォーム。
/// 下部フッターは AddBookView と共通の `AddBookFooter` を使う。
public struct BookPreviewAddView: View {
    private let container: PresentationContainer
    private let router: Router
    private let catalog: CatalogBook
    private let alreadyRegistered: Bool
    @State private var viewModel: AddBookViewModel

    public init(container: PresentationContainer, router: Router, catalog: CatalogBook, alreadyRegistered: Bool = false) {
        self.container = container
        self.router = router
        self.catalog = catalog
        self.alreadyRegistered = alreadyRegistered
        let vm = AddBookViewModel(container: container)
        vm.selectedCatalog = catalog
        self._viewModel = State(initialValue: vm)
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    bookCard
                    DatePicker("購入日", selection: $viewModel.purchasedAt, displayedComponents: .date)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
        .background(ColorToken.boardBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            AddBookFooter(viewModel: viewModel, router: router)
        }
        .task { await viewModel.loadBoards() }
    }

    private var header: some View {
        HStack {
            Text("書籍の詳細")
                .font(FontToken.screenTitle())
                .foregroundStyle(ColorToken.ink)
            Spacer()
            if alreadyRegistered {
                Text("登録済み")
                    .font(FontToken.caption())
                    .foregroundStyle(ColorToken.inkTertiary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(ColorToken.surface))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var bookCard: some View {
        HStack(alignment: .top, spacing: 16) {
            CoverImageView(
                cover: catalog.metadata.remoteCoverURL.map(CoverImage.remote) ?? .none,
                title: catalog.metadata.title,
                loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil }
            )
            .frame(width: 110, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: ColorToken.ink.opacity(0.12), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(catalog.metadata.title)
                    .font(FontToken.bookTitleLarge())
                    .foregroundStyle(ColorToken.ink)
                    .multilineTextAlignment(.leading)
                if !catalog.metadata.authors.isEmpty {
                    Text(catalog.metadata.authors.joined(separator: ", "))
                        .font(FontToken.bodyRegular())
                        .foregroundStyle(ColorToken.inkSecondary)
                }
                if let publisher = catalog.metadata.publisher {
                    Text(publisher)
                        .font(FontToken.caption())
                        .foregroundStyle(ColorToken.inkTertiary)
                }
                if let page = catalog.metadata.pageCount {
                    Text(verbatim: "\(page)ページ")
                        .font(FontToken.caption())
                        .foregroundStyle(ColorToken.inkTertiary)
                }
                if let isbn = catalog.metadata.isbn {
                    Text(verbatim: "ISBN: \(isbn.value)")
                        .font(FontToken.caption())
                        .foregroundStyle(ColorToken.inkTertiary)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
}

#endif
