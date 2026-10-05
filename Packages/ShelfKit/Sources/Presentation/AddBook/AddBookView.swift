#if canImport(UIKit)
import SwiftUI
import Domain
import Application

public struct AddBookView: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: AddBookViewModel
    @State private var showScanner = false
    @State private var showManualEntry = false
    @State private var showCreateBoard = false
    @State private var newBoardName = ""
    @State private var showMemoList = false

    public init(container: PresentationContainer, router: Router, initialKeyword: String = "") {
        self.container = container
        self.router = router
        self._viewModel = State(initialValue: AddBookViewModel(container: container, initialKeyword: initialKeyword))
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            contentBody
        }
        .background(ColorToken.boardBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    /// 本棚/積読/カレンダーと同じ screenTitle のヘッダー。右端にメモ画面への遷移ボタン。
    private var header: some View {
        HStack {
            Text("本を追加")
                .font(FontToken.screenTitle())
                .foregroundStyle(ColorToken.ink)
            Spacer()
            Button { showMemoList = true } label: {
                Image(systemName: "list.bullet.clipboard")
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorToken.surface))
                    .foregroundStyle(ColorToken.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("気になる本メモを開く")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var contentBody: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchBar
                    if viewModel.isSearching {
                        ProgressView()
                    }
                    if let error = viewModel.errorMessage, !viewModel.isSearching {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(FontToken.bodyRegular())
                                .foregroundStyle(ColorToken.sunday)
                                .multilineTextAlignment(.leading)
                            Button("手動で登録する") { showManualEntry = true }
                                .buttonStyle(.borderedProminent)
                                .tint(ColorToken.accent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.surface))
                    } else if !viewModel.results.isEmpty {
                        resultsList
                    } else if !viewModel.keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSearching {
                        VStack(spacing: 8) {
                            Text("見つかりませんでした").font(FontToken.bodyRegular()).foregroundStyle(ColorToken.inkSecondary)
                            Button("手動で登録する") { showManualEntry = true }
                                .buttonStyle(.borderedProminent)
                                .tint(ColorToken.accent)
                        }
                        .frame(maxWidth: .infinity).padding()
                    }
                    DatePicker("購入日", selection: $viewModel.purchasedAt, displayedComponents: .date)
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    destinationSegment
                    boardPicker
                    actionButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ColorToken.boardBackground)
            }
            .task { await viewModel.loadBoards() }
            .task {
                // 初期キーワードが与えられていれば自動で検索を走らせる（メモからの遷移で使う）。
                let trimmed = viewModel.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, viewModel.results.isEmpty {
                    await viewModel.search(keyword: trimmed)
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { isbn in
                    showScanner = false
                    Task { await viewModel.lookupISBN(isbn) }
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView { entry, coverData in
                    Task {
                        if await viewModel.addManual(entry: entry, coverImageData: coverData) != nil {
                            // 追加完了したら対応するタブに遷移。タブ画面なので dismiss は不要。
                            router.selectedTab = viewModel.destination == .pile ? .pile : .shelf
                            showManualEntry = false
                        }
                    }
                }
            }
            .alert(viewModel.destination == .shelf ? "新しい本棚を作成" : "新しい積読フォルダを作成", isPresented: $showCreateBoard) {
                TextField(viewModel.destination == .shelf ? "本棚の名前" : "フォルダ名", text: $newBoardName)
                Button("作成") {
                    let name = newBoardName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    let captured = name
                    Task {
                        await viewModel.createBoard(name: captured)
                        newBoardName = ""
                    }
                }
                Button("キャンセル", role: .cancel) { newBoardName = "" }
            }
            .navigationDestination(isPresented: $showMemoList) {
                MemoListView(container: container, router: router)
            }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(ColorToken.inkSecondary)
                TextField("タイトル・著者・ISBN", text: $viewModel.keyword, onEditingChanged: { _ in })
                    .textInputAutocapitalization(.never)
                    .onChange(of: viewModel.keyword) { _, _ in
                        viewModel.onKeywordChanged()
                    }
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.surface))

            Button { showScanner = true } label: {
                Image(systemName: "barcode.viewfinder")
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.ink))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("バーコード読み取り")

            Button { showManualEntry = true } label: {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("手動で登録")
        }
    }

    private var resultsList: some View {
        VStack(spacing: 8) {
            ForEach(Array(viewModel.results.enumerated()), id: \.offset) { _, item in
                Button {
                    if !item.alreadyRegistered {
                        viewModel.selectedCatalog = item.catalog
                    }
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
                            Text(item.catalog.metadata.title).font(FontToken.sectionTitle()).foregroundStyle(ColorToken.ink).lineLimit(2)
                            if !item.catalog.metadata.authors.isEmpty {
                                Text(item.catalog.metadata.authors.joined(separator: ", "))
                                    .font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary).lineLimit(1)
                            }
                            if let page = item.catalog.metadata.pageCount {
                                Text("\(page)ページ").font(FontToken.caption()).foregroundStyle(ColorToken.inkTertiary)
                            }
                        }
                        Spacer()
                        if item.alreadyRegistered {
                            Text("登録済み").font(FontToken.caption()).foregroundStyle(ColorToken.inkTertiary)
                        } else if viewModel.selectedCatalog?.metadata.catalogID == item.catalog.metadata.catalogID {
                            Image(systemName: "checkmark").foregroundStyle(ColorToken.accent)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.selectedCatalog?.metadata.catalogID == item.catalog.metadata.catalogID ? ColorToken.ink : .clear, lineWidth: 2)
                    )
                    .opacity(item.alreadyRegistered ? 0.5 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(item.alreadyRegistered)
            }
        }
    }

    /// 本棚／積読のコンパクトな 2 択セグメント。フッターに置くため見出しなし。
    private var destinationSegment: some View {
        HStack(spacing: 4) {
            destinationSegmentButton(.shelf, title: "本棚")
            destinationSegmentButton(.pile, title: "積読")
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.segmentTrack))
    }

    private func destinationSegmentButton(_ destination: AddBookViewModel.Destination, title: String) -> some View {
        let selected = viewModel.destination == destination
        return Button {
            viewModel.destination = destination
        } label: {
            Text(title)
                .font(FontToken.sectionTitle())
                .foregroundStyle(selected ? .white : ColorToken.inkSecondary)
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(selected ? ColorToken.accent : .clear))
        }
        .buttonStyle(.plain)
    }

    /// フッターに置くコンパクトなフォルダピッカー。
    private var boardPicker: some View {
        let isShelf = viewModel.destination == .shelf
        let addLabel = isShelf ? "本棚を追加" : "フォルダを追加"
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !isShelf {
                    Chip(title: "未分類", isSelected: viewModel.selectedPileBoardID == nil) {
                        viewModel.selectedPileBoardID = nil
                    }
                }
                ForEach(viewModel.boardsForCurrentDestination) { board in
                    let selected = (isShelf ? viewModel.selectedShelfBoardID : viewModel.selectedPileBoardID) == board.id
                    Chip(title: board.name, isSelected: selected) {
                        if isShelf { viewModel.selectedShelfBoardID = board.id }
                        else { viewModel.selectedPileBoardID = board.id }
                    }
                }
                Button {
                    showCreateBoard = true
                } label: {
                    Label(addLabel, systemImage: "plus")
                        .font(FontToken.label())
                        .foregroundStyle(ColorToken.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(ColorToken.surface))
                        .overlay(Capsule().stroke(ColorToken.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
    }

    private var actionButton: some View {
        let label = viewModel.destination == .pile ? "積読ゾーンに落とす" : "本棚に貼る"
        return Button {
            Task {
                if await viewModel.addSelected() != nil {
                    // タブ画面なので dismiss せず対応タブへ遷移。
                    router.selectedTab = viewModel.destination == .pile ? .pile : .shelf
                }
            }
        } label: {
            Text(viewModel.isAdding ? "追加中..." : label)
                .font(FontToken.sectionTitle())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 16).fill(ColorToken.accent))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedCatalog == nil || viewModel.isAdding)
        .opacity(viewModel.selectedCatalog == nil ? 0.5 : 1.0)
    }
}

#endif
