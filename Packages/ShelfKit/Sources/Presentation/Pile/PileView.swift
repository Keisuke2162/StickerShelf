#if canImport(UIKit)
import SwiftUI
import Domain

public struct PileView: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: PileViewModel
    @State private var longPressTarget: BookID?
    @State private var pileItems: [PileDynamicsView.Item] = []
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var showDeleteFolderConfirm = false

    public init(container: PresentationContainer, router: Router) {
        self.container = container
        self.router = router
        self._viewModel = State(initialValue: PileViewModel(container: container))
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            folderChips
            stats
            if viewModel.display == .pile {
                pileBoard
            } else {
                listView
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorToken.pileBackground.ignoresSafeArea())
        .task { await viewModel.reload() }
        .task(id: router.selectedTab) {
            if router.selectedTab == .pile { await viewModel.start() }
        }
        .task(id: viewModel.books) {
            await refreshItems()
        }
        .alert("新しいフォルダを作成", isPresented: $showCreateFolder) {
            TextField("フォルダ名（例: 漫画 / あとで読む）", text: $newFolderName)
            Button("作成") {
                let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let captured = name
                Task {
                    await viewModel.createBoard(name: captured)
                    newFolderName = ""
                }
            }
            Button("キャンセル", role: .cancel) { newFolderName = "" }
        }
        .alert("このフォルダを削除しますか？", isPresented: $showDeleteFolderConfirm) {
            Button("削除", role: .destructive) {
                Task { await viewModel.deleteCurrentBoard() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("フォルダに属していた本は「未分類」になります。本自体は残ります。")
        }
        .confirmationDialog(
            "この本をどうしますか？",
            isPresented: Binding(get: { longPressTarget != nil }, set: { if !$0 { longPressTarget = nil } }),
            titleVisibility: .visible
        ) {
            if let id = longPressTarget {
                Button("読み始める") { Task { await viewModel.startReading(id: id); longPressTarget = nil } }
                Button("読んだことにする") { Task { await viewModel.markFinished(id: id); longPressTarget = nil } }
                ForEach(viewModel.boards) { board in
                    if board.id != viewModel.books.first(where: { $0.id == id })?.boardID {
                        Button("「\(board.name)」へ移動") {
                            Task { await viewModel.moveToBoard(id: id, boardID: board.id); longPressTarget = nil }
                        }
                    }
                }
                if viewModel.books.first(where: { $0.id == id })?.boardID != nil {
                    Button("未分類に戻す") {
                        Task { await viewModel.moveToBoard(id: id, boardID: nil); longPressTarget = nil }
                    }
                }
                Button("削除", role: .destructive) { Task { await viewModel.deleteBook(id: id); longPressTarget = nil } }
                Button("キャンセル", role: .cancel) { longPressTarget = nil }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("積読")
                .font(FontToken.screenTitle())
                .foregroundStyle(ColorToken.ink)
            Spacer()
            if viewModel.selectedBoardID != nil {
                Button {
                    showDeleteFolderConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(ColorToken.surface))
                        .foregroundStyle(ColorToken.sunday)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("現在のフォルダを削除")
            }
            Button {
                viewModel.display = viewModel.display == .pile ? .list : .pile
            } label: {
                Image(systemName: viewModel.display == .pile ? "list.bullet" : "square.stack.3d.down.right")
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorToken.surface))
                    .foregroundStyle(ColorToken.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("表示切替")
        }
    }

    private var folderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "すべて", isSelected: viewModel.selectedBoardID == nil) {
                    viewModel.select(boardID: nil)
                }
                ForEach(viewModel.boards) { board in
                    Chip(title: board.name, isSelected: viewModel.selectedBoardID == board.id) {
                        viewModel.select(boardID: board.id)
                    }
                }
                Button {
                    showCreateFolder = true
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
                .accessibilityLabel("フォルダを追加")
            }
            .padding(.horizontal, 4)
        }
    }

    private var stats: some View {
        statCard(title: viewModel.selectedBoardID == nil ? "積読（全体）" : "このフォルダ", value: "\(viewModel.books.count)冊")
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(FontToken.caption()).foregroundStyle(ColorToken.inkSecondary)
            Text(value).font(FontToken.statNumber()).foregroundStyle(ColorToken.ink)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(ColorToken.surface))
    }

    private var pileBoard: some View {
        ZStack(alignment: .top) {
            PileBackground()
                .clipShape(RoundedRectangle(cornerRadius: 14))

            PileDynamicsView(
                items: pileItems,
                onTap: { id in router.detailBookID = id },
                onLongPress: { id in longPressTarget = id }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if pileItems.isEmpty && !viewModel.isLoading {
                Text(viewModel.selectedBoardID == nil
                     ? "積読の本がありません。＋ボタンから追加してください。"
                     : "このフォルダはまだ空です。")
                    .font(FontToken.bodyRegular())
                    .foregroundStyle(ColorToken.inkSecondary)
                    .padding(.top, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refreshItems() async {
        var out: [PileDynamicsView.Item] = []
        out.reserveCapacity(viewModel.books.count)
        for book in viewModel.books {
            let data = (try? await container.coverImages.imageData(for: book.cover)) ?? nil
            let size = pileCellSize(for: data, bookID: book.id)
            out.append(.init(id: book.id, title: book.metadata.title, size: size, imageData: data))
        }
        pileItems = out
    }

    /// 書影の実アスペクト比に沿って、積読セルのサイズを決める。
    /// 長辺 74pt 固定・短辺は実比に合わせて 36pt〜74pt にクランプ。
    /// 画像が無い本は従来の縦長 52×74 fallback（落ちもののバリエーション維持のため、
    /// BookID の下位ビットで 1 割だけ横長 74×52 に振る）。
    private func pileCellSize(for data: Data?, bookID: BookID) -> CGSize {
        let longEdge: CGFloat = 74
        let minShortEdge: CGFloat = 36
        if let data, let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 {
            let w = image.size.width
            let h = image.size.height
            if h >= w {
                let short = max(minShortEdge, min(longEdge, longEdge * (w / h)))
                return CGSize(width: short, height: longEdge)
            } else {
                let short = max(minShortEdge, min(longEdge, longEdge * (h / w)))
                return CGSize(width: longEdge, height: short)
            }
        }
        let firstByte = bookID.rawValue.uuid.0
        return (firstByte % 10) < 9 ? CGSize(width: 52, height: 74) : CGSize(width: 74, height: 52)
    }

    private var listView: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(viewModel.books.sorted { viewModel.daysInPile(for: $0) > viewModel.daysInPile(for: $1) }) { book in
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
                                Text(book.metadata.authors.joined(separator: ", "))
                                    .font(FontToken.caption())
                                    .foregroundStyle(ColorToken.inkSecondary)
                            }
                            Spacer()
                            Text("\(viewModel.daysInPile(for: book))日")
                                .font(FontToken.label())
                                .foregroundStyle(ColorToken.accent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 14).fill(ColorToken.surface))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("読み始める") { Task { await viewModel.startReading(id: book.id) } }
                        Button("読んだことにする") { Task { await viewModel.markFinished(id: book.id) } }
                        ForEach(viewModel.boards) { board in
                            if board.id != book.boardID {
                                Button("「\(board.name)」へ移動") { Task { await viewModel.moveToBoard(id: book.id, boardID: board.id) } }
                            }
                        }
                        if book.boardID != nil {
                            Button("未分類に戻す") { Task { await viewModel.moveToBoard(id: book.id, boardID: nil) } }
                        }
                        Button("削除", role: .destructive) { Task { await viewModel.deleteBook(id: book.id) } }
                    }
                }
            }
        }
    }
}

/// 積読ボードの背景：pileBackground 地 + 26pt 間隔の方眼 + 床 4pt
private struct PileBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(ColorToken.pileBackground)))
            let grid = Color(ColorToken.pileGrid)
            var path = Path()
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += 26
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += 26
            }
            context.stroke(path, with: .color(grid), lineWidth: 1)
            let floorRect = CGRect(x: 0, y: size.height - 4, width: size.width, height: 4)
            context.fill(Path(floorRect), with: .color(Color(ColorToken.pileFloor)))
        }
        .allowsHitTesting(false)
    }
}

#endif
