#if canImport(UIKit)
import SwiftUI
import Domain

public struct ShelfView: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: ShelfViewModel
    @State private var showCreateBoard = false
    @State private var newBoardName = ""
    @State private var editingBoard: Board?
    @Environment(ThemeStore.self) private var theme

    public init(container: PresentationContainer, router: Router) {
        self.container = container
        self.router = router
        self._viewModel = State(initialValue: ShelfViewModel(container: container))
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            boardChips
            if viewModel.display == .board {
                board
            } else {
                listView
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.backgroundColor.ignoresSafeArea())
        .task { await viewModel.reload() }
        .task(id: router.selectedTab) {
            if router.selectedTab == .shelf { await viewModel.start() }
        }
        .alert("新しい本棚を作成", isPresented: $showCreateBoard) {
            TextField("本棚の名前", text: $newBoardName)
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
        .sheet(item: $editingBoard) { b in
            BoardEditorView(container: container, board: b)
        }
    }

    private var header: some View {
        HStack {
            Text("本棚")
                .font(FontToken.screenTitle())
                .foregroundStyle(ColorToken.ink)
            Spacer()
            Button {
                viewModel.display = viewModel.display == .board ? .list : .board
            } label: {
                Image(systemName: viewModel.display == .board ? "list.bullet" : "square.on.square")
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorToken.surface))
                    .foregroundStyle(ColorToken.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("表示切替")

            Button {
                router.isAddingBook = true
            } label: {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorToken.actionBlue))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("本を追加")
        }
    }


    private var boardChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // フォルダが増えてもすぐ押せるよう追加ボタンは左端に固定。
                Button {
                    showCreateBoard = true
                } label: {
                    Image(systemName: "plus")
                        .font(FontToken.label())
                        .foregroundStyle(ColorToken.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(ColorToken.surface))
                        .overlay(Capsule().stroke(ColorToken.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel("本棚を追加")
                ForEach(viewModel.boards) { board in
                    Chip(
                        title: board.name,
                        isSelected: viewModel.selectedBoardID == board.id,
                        action: { viewModel.select(boardID: board.id) },
                        onLongPress: { editingBoard = board }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var board: some View {
        let appearance = currentBoard?.appearance ?? .default
        return GeometryReader { geo in
            ZStack {
                BoardBackgroundView(appearance: appearance)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 空白タップで選択解除。長押しで現在のボード編集画面を開く。
                // ステッカー（上の層）に触れている場合はそちらの gesture が優先される。
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedStickerID = nil
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        if let board = currentBoard {
                            editingBoard = board
                        }
                    }

                if viewModel.boards.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Text("本棚がありません").font(FontToken.bodyRegular()).foregroundStyle(ColorToken.inkSecondary)
                        Button {
                            showCreateBoard = true
                        } label: {
                            Label("本棚を作成", systemImage: "plus")
                                .font(FontToken.sectionTitle())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(ColorToken.accent))
                        }
                        .buttonStyle(.plain)
                    }
                } else if viewModel.books.isEmpty && !viewModel.isLoading {
                    EmptyShelfPlaceholder {
                        router.isAddingBook = true
                    }
                }

                // VM の books は既に zIndex 昇順でソート済み（FetchShelfUseCase 側で保証）
                ForEach(viewModel.books) { book in
                    if let placement = book.sticker {
                        StickerDraggable(
                            book: book,
                            placement: placement,
                            boardSize: geo.size,
                            viewModel: viewModel,
                            router: router,
                            container: container
                        )
                        .zIndex(Double(placement.zIndex))
                    }
                }
            }
            .coordinateSpace(name: "stickerBoard")
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(ColorToken.hairline, lineWidth: 1))
            .shadow(color: ColorToken.ink.opacity(0.06), radius: 10, y: 4)
        }
    }

    /// 現在選択中のボード（表示用）。
    private var currentBoard: Board? {
        viewModel.boards.first { $0.id == viewModel.selectedBoardID }
    }

    private var listView: some View {
        ScrollView {
            VStack(spacing: 8) {
                if viewModel.books.isEmpty && !viewModel.isLoading {
                    Text("この本棚はまだ空です")
                        .font(FontToken.bodyRegular())
                        .foregroundStyle(ColorToken.inkSecondary)
                        .padding(.top, 32)
                }
                ForEach(viewModel.books) { book in
                    Button {
                        router.detailBookID = book.id
                    } label: {
                        HStack(spacing: 12) {
                            CoverImageView(
                                cover: book.cover,
                                title: book.metadata.title,
                                loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil }
                            )
                            .frame(width: 40, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.metadata.title)
                                    .font(FontToken.sectionTitle())
                                    .foregroundStyle(ColorToken.ink)
                                    .lineLimit(2)
                                if !book.metadata.authors.isEmpty {
                                    Text(book.metadata.authors.joined(separator: ", "))
                                        .font(FontToken.caption())
                                        .foregroundStyle(ColorToken.inkSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 14).fill(ColorToken.surface))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("最前面へ") { Task { await viewModel.didTouchSticker(id: book.id) } }
                        Button("積読に戻す") { Task { await viewModel.returnToPile(id: book.id) } }
                        Button("削除", role: .destructive) { Task { await viewModel.deleteBook(id: book.id) } }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct EmptyShelfPlaceholder: View {
    let onAdd: () -> Void

    var body: some View {
        Button("＋ 追加", action: onAdd)
            .buttonStyle(.bordered)
            .tint(ColorToken.ink)
            .padding()
    }
}

#endif
