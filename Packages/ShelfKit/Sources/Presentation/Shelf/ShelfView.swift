#if canImport(UIKit)
import SwiftUI
import Domain

public struct ShelfView: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: ShelfViewModel
    @State private var showCreateBoard = false
    @State private var newBoardName = ""
    @State private var showDeleteBoardConfirm = false

    public init(container: PresentationContainer, router: Router) {
        self.container = container
        self.router = router
        self._viewModel = State(initialValue: ShelfViewModel(container: container))
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            boardChips
            board
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorToken.boardBackground.ignoresSafeArea())
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
        .alert("この本棚を削除しますか？", isPresented: $showDeleteBoardConfirm) {
            Button("削除", role: .destructive) {
                Task { await viewModel.deleteCurrentBoard() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("本棚に貼られていた本は「所属なし」になります。本自体は残ります。")
        }
    }

    private var header: some View {
        HStack {
            Text("本棚")
                .font(FontToken.screenTitle())
                .foregroundStyle(ColorToken.ink)
            Spacer()
            if viewModel.boards.count > 1 && viewModel.selectedBoardID != nil {
                Button {
                    showDeleteBoardConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(ColorToken.surface))
                        .foregroundStyle(ColorToken.sunday)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("現在の本棚を削除")
            }
            Button {
                Task { await viewModel.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorToken.surface))
                    .foregroundStyle(ColorToken.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("再読み込み")
        }
    }


    private var boardChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.boards) { board in
                    Chip(title: board.name, isSelected: viewModel.selectedBoardID == board.id) {
                        viewModel.select(boardID: board.id)
                    }
                }
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
            }
            .padding(.horizontal, 4)
        }
    }

    private var board: some View {
        GeometryReader { geo in
            ZStack {
                DotGridBackground()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                        router.selectedTab = .pile
                    } onAdd: {
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
            .clipped()
        }
    }
}

private struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            let dotColor = Color(ColorToken.boardDot)
            for x in stride(from: spacing / 2, to: size.width, by: spacing) {
                for y in stride(from: spacing / 2, to: size.height, by: spacing) {
                    let rect = CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct EmptyShelfPlaceholder: View {
    let onPile: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("まだ本が貼られていません")
                .font(FontToken.bodyRegular())
                .foregroundStyle(ColorToken.inkSecondary)
            HStack(spacing: 12) {
                Button("積読から読み始める", action: onPile)
                    .buttonStyle(.borderedProminent)
                    .tint(ColorToken.accent)
                Button("＋ 追加", action: onAdd)
                    .buttonStyle(.bordered)
                    .tint(ColorToken.ink)
            }
        }
        .padding()
    }
}

#endif
