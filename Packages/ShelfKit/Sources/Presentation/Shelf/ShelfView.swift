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
    /// キャンバス表示用。viewport は固定、内側のキャンバスを拡大 (2.5倍) してパン/ズームする。
    @State private var boardScale: CGFloat = 1.0
    @State private var boardOffset: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1.0
    @GestureState private var panDelta: CGSize = .zero
    @Environment(ThemeStore.self) private var theme

    private let canvasMultiplier: CGFloat = 2.5
    private let minScale: CGFloat = 0.4
    private let maxScale: CGFloat = 1.6

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
            let viewport = geo.size
            let canvas = CGSize(width: viewport.width * canvasMultiplier,
                                height: viewport.height * canvasMultiplier)
            // ピンチ中もスケール下限を強制して、キャンバスが viewport より小さく表示されないようにする。
            let effectiveScale = (boardScale * pinchDelta).clamped(to: minScale...maxScale)
            // ドラッグ中もキャンバスが viewport の外に出ないよう即時クランプする。
            let maxOffsetX = max(0, (canvas.width * effectiveScale - viewport.width) / 2)
            let maxOffsetY = max(0, (canvas.height * effectiveScale - viewport.height) / 2)
            let effectiveOffset = CGSize(
                width: (boardOffset.width + panDelta.width).clamped(to: -maxOffsetX...maxOffsetX),
                height: (boardOffset.height + panDelta.height).clamped(to: -maxOffsetY...maxOffsetY)
            )

            // キャンバス（widgets の実配置領域）。
            let canvasView = ZStack {
                BoardBackgroundView(appearance: appearance)
                    .frame(width: canvas.width, height: canvas.height)

                // 空白領域のタップ/長押し/パン/ピンチ。ステッカー上は子要素優先で発火しない。
                Color.clear
                    .frame(width: canvas.width, height: canvas.height)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectedStickerID = nil }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        if let board = currentBoard { editingBoard = board }
                    }
                    .simultaneousGesture(magnifyBoardGesture)
                    .simultaneousGesture(panBoardGesture(viewport: viewport, canvas: canvas))

                if viewModel.boards.isEmpty && !viewModel.isLoading {
                    emptyBoardsPlaceholder
                } else if viewModel.books.isEmpty && !viewModel.isLoading {
                    EmptyShelfPlaceholder { router.isAddingBook = true }
                }

                // VM の books は既に zIndex 昇順でソート済み（FetchShelfUseCase 側で保証）
                ForEach(viewModel.books) { book in
                    if let placement = book.sticker {
                        StickerDraggable(
                            book: book,
                            placement: placement,
                            boardSize: canvas,
                            viewModel: viewModel,
                            router: router,
                            container: container
                        )
                        .zIndex(Double(placement.zIndex))
                    }
                }
            }
            .frame(width: canvas.width, height: canvas.height)
            // stickerBoard 座標系は変換 (scale/offset) の内側で固定する。
            // こうすることでステッカーの変形ハンドルがキャンバス座標系で位置を測り、
            // パン/ズーム適用後も中心位置と一致して回転・拡縮の方向が逆転しない。
            .coordinateSpace(name: "stickerBoard")

            canvasView
                .scaleEffect(effectiveScale)
                .offset(effectiveOffset)
                .frame(width: viewport.width, height: viewport.height, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(ColorToken.hairline, lineWidth: 1))
                .shadow(color: ColorToken.ink.opacity(0.06), radius: 10, y: 4)
        }
    }

    @ViewBuilder
    private var emptyBoardsPlaceholder: some View {
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
    }

    private var magnifyBoardGesture: some Gesture {
        MagnifyGesture()
            .updating($pinchDelta) { value, state, _ in state = value.magnification }
            .onEnded { value in
                boardScale = (boardScale * value.magnification).clamped(to: minScale...maxScale)
            }
    }

    private func panBoardGesture(viewport: CGSize, canvas: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($panDelta) { value, state, _ in state = value.translation }
            .onEnded { value in
                let scale = boardScale
                let maxX = max(0, (canvas.width * scale - viewport.width) / 2)
                let maxY = max(0, (canvas.height * scale - viewport.height) / 2)
                boardOffset = CGSize(
                    width: (boardOffset.width + value.translation.width).clamped(to: -maxX...maxX),
                    height: (boardOffset.height + value.translation.height).clamped(to: -maxY...maxY)
                )
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
