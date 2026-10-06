#if canImport(UIKit)
import SwiftUI
import Domain
import Application

/// 気になる本メモから遷移する「検索結果一覧」画面。
/// 結果の 1 冊をタップすると `BookPreviewAddView` へ push し、本棚/積読に追加できる。
public struct MemoSearchResultView: View {
    private let container: PresentationContainer
    private let router: Router
    private let keyword: String
    @State private var viewModel: AddBookViewModel
    @Environment(ThemeStore.self) private var theme

    public init(container: PresentationContainer, router: Router, keyword: String) {
        self.container = container
        self.router = router
        self.keyword = keyword
        self._viewModel = State(initialValue: AddBookViewModel(container: container, initialKeyword: keyword))
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            content
            Spacer(minLength: 0)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.search(keyword: keyword)
        }
    }

    private var header: some View {
        HStack {
            Text(verbatim: "「\(keyword)」の検索結果")
                .font(FontToken.screenTitle())
                .foregroundStyle(ColorToken.ink)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching {
            ProgressView().padding(.top, 40)
        } else if let error = viewModel.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(FontToken.bodyRegular())
                .foregroundStyle(ColorToken.sunday)
                .padding(.horizontal, 20)
        } else if viewModel.results.isEmpty {
            Text("この条件では見つかりませんでした")
                .font(FontToken.bodyRegular())
                .foregroundStyle(ColorToken.inkSecondary)
                .padding(.top, 40)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.offset) { _, item in
                        resultRow(item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
        }
    }

    private func resultRow(_ item: SearchCatalogOutput.Item) -> some View {
        NavigationLink {
            BookPreviewAddView(container: container, router: router, catalog: item.catalog, alreadyRegistered: item.alreadyRegistered)
        } label: {
            HStack(spacing: 12) {
                CoverImageView(
                    cover: item.catalog.metadata.remoteCoverURL.map(CoverImage.remote) ?? .none,
                    title: item.catalog.metadata.title,
                    loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil }
                )
                .frame(width: 40, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.catalog.metadata.title)
                        .font(FontToken.sectionTitle())
                        .foregroundStyle(ColorToken.ink)
                        .lineLimit(2)
                    if !item.catalog.metadata.authors.isEmpty {
                        Text(item.catalog.metadata.authors.joined(separator: ", "))
                            .font(FontToken.caption())
                            .foregroundStyle(ColorToken.inkSecondary)
                            .lineLimit(1)
                    }
                    if let page = item.catalog.metadata.pageCount {
                        Text(verbatim: "\(page)ページ")
                            .font(FontToken.caption())
                            .foregroundStyle(ColorToken.inkTertiary)
                    }
                }
                Spacer()
                if item.alreadyRegistered {
                    Text("登録済み").font(FontToken.caption()).foregroundStyle(ColorToken.inkTertiary)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorToken.inkTertiary)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.surface))
            .opacity(item.alreadyRegistered ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(item.alreadyRegistered)
    }
}

#endif
