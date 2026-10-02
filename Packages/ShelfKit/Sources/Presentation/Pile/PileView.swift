#if canImport(UIKit)
import SwiftUI
import Domain

public struct PileView: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: PileViewModel
    @State private var longPressTarget: BookID?
    @State private var pileItems: [PileDynamicsView.Item] = []

    public init(container: PresentationContainer, router: Router) {
        self.container = container
        self.router = router
        self._viewModel = State(initialValue: PileViewModel(container: container))
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            SegmentedSwitch(
                options: [
                    .init(id: Router.BoardMode.shelf, title: "本棚"),
                    .init(id: Router.BoardMode.pile, title: "積読", badge: viewModel.books.count)
                ],
                selection: Binding(get: { router.boardMode }, set: { router.boardMode = $0 })
            )
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
        .task(id: router.boardMode) {
            if router.boardMode == .pile { await viewModel.start() }
        }
        .task(id: viewModel.books) {
            await refreshItems()
        }
        .confirmationDialog(
            "この本をどうしますか？",
            isPresented: Binding(get: { longPressTarget != nil }, set: { if !$0 { longPressTarget = nil } }),
            titleVisibility: .visible
        ) {
            if let id = longPressTarget {
                Button("読み始める") { Task { await viewModel.startReading(id: id); longPressTarget = nil } }
                Button("読んだことにする") { Task { await viewModel.markFinished(id: id); longPressTarget = nil } }
                Button("削除", role: .destructive) { Task { await viewModel.deleteBook(id: id); longPressTarget = nil } }
                Button("キャンセル", role: .cancel) { longPressTarget = nil }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("本棚")
                .font(FontToken.screenTitle())
                .foregroundStyle(ColorToken.ink)
            Spacer()
            Button {
                viewModel.display = viewModel.display == .pile ? .list : .pile
            } label: {
                Image(systemName: viewModel.display == .pile ? "list.bullet" : "square.stack.3d.down.right")
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 22).fill(ColorToken.surface))
                    .foregroundStyle(ColorToken.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("表示切替")
        }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            statCard(title: "積読", value: "\(viewModel.statistics.count)冊")
            statCard(title: "平均積読日数", value: "\(viewModel.statistics.averageDays)日")
            statCard(title: "今月増えた", value: "+\(viewModel.statistics.addedThisMonth)冊")
        }
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
            // 方眼 + 床
            PileBackground()
                .clipShape(RoundedRectangle(cornerRadius: 14))

            PileDynamicsView(
                items: pileItems,
                onTap: { id in router.detailBookID = id },
                onLongPress: { id in longPressTarget = id }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if pileItems.isEmpty && !viewModel.isLoading {
                Text("積読の本がありません。＋ボタンから追加してください。")
                    .font(FontToken.bodyRegular())
                    .foregroundStyle(ColorToken.inkSecondary)
                    .padding(.top, 40)
            } else {
                Text("長押しで「読み始める」→ 本棚に貼られます")
                    .font(FontToken.caption())
                    .foregroundStyle(ColorToken.ink)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(ColorToken.ink.opacity(0.08)))
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func refreshItems() async {
        var out: [PileDynamicsView.Item] = []
        out.reserveCapacity(viewModel.books.count)
        for book in viewModel.books {
            let firstByte = book.id.rawValue.uuid.0
            let isVertical = (firstByte % 10) < 6
            let data = (try? await container.coverImages.imageData(for: book.cover)) ?? nil
            out.append(.init(id: book.id, title: book.metadata.title, isVertical: isVertical, imageData: data))
        }
        pileItems = out
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
            // 背景
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(ColorToken.pileBackground)))
            // 方眼線（1pt、26pt 間隔、pileGrid）
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
            // 床 (4pt, pileFloor)
            let floorRect = CGRect(x: 0, y: size.height - 4, width: size.width, height: 4)
            context.fill(Path(floorRect), with: .color(Color(ColorToken.pileFloor)))
        }
        .allowsHitTesting(false)
    }
}

#endif
