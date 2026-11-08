#if canImport(UIKit)
import SwiftUI
import Domain

/// 本屋などで気になった本のタイトルを連続メモし、後から検索して本棚/積読に追加するための画面。
/// 本タブ (AddBookView) から NavigationLink で遷移する想定。
public struct MemoListView: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: MemoListViewModel
    @FocusState private var inputFocused: Bool
    @Environment(ThemeStore.self) private var theme

    public init(container: PresentationContainer, router: Router) {
        self.container = container
        self.router = router
        self._viewModel = State(initialValue: MemoListViewModel(container: container))
    }

    public var body: some View {
        VStack(spacing: 0) {
            inputBar
            memosList
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationTitle("気になる本メモ")
        .navigationBarTitleDisplayMode(.inline)
        // 画面の空白部分 or リストタップ時にキーボードを閉じる。
        // simultaneousGesture にすることで NavigationLink のタップとも両立する。
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { inputFocused = false })
        .task { await viewModel.reload() }
        .task { await viewModel.start() }
        .onAppear { inputFocused = true }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.and.list.clipboard")
                .foregroundStyle(ColorToken.inkSecondary)
            TextField("本のタイトルを入力して Enter", text: $viewModel.input)
                .focused($inputFocused)
                .submitLabel(.done)
                .onSubmit {
                    Task {
                        await viewModel.submitCurrentInput()
                        // 連続入力のためキーボードを閉じず、フォーカスを維持する。
                        inputFocused = true
                    }
                }
                .textInputAutocapitalization(.sentences)
            if !viewModel.input.isEmpty {
                Button {
                    viewModel.input = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ColorToken.inkTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("入力をクリア")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.surface))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var memosList: some View {
        if viewModel.memos.isEmpty {
            VStack(spacing: 8) {
                Spacer(minLength: 32)
                Text("まだメモはありません")
                    .font(FontToken.bodyRegular())
                    .foregroundStyle(ColorToken.inkSecondary)
                Text("本屋さんで気になった本のタイトルを打ち込んで Enter")
                    .font(FontToken.caption())
                    .foregroundStyle(ColorToken.inkTertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.memos) { memo in
                        NavigationLink {
                            MemoSearchResultView(container: container, router: router, keyword: memo.title)
                        } label: {
                            memoRow(memo)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
    }

    private func memoRow(_ memo: TitleMemo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ColorToken.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(memo.title)
                    .font(FontToken.sectionTitle())
                    .foregroundStyle(ColorToken.ink)
                    .lineLimit(2)
                Text(memo.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(FontToken.caption())
                    .foregroundStyle(ColorToken.inkTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(ColorToken.inkTertiary)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.surface))
        .contextMenu {
            Button("削除", role: .destructive) {
                let id = memo.id
                Task { await viewModel.delete(id: id) }
            }
        }
    }
}

#endif
