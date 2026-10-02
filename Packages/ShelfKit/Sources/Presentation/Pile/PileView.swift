#if canImport(UIKit)
import SwiftUI
import SpriteKit
import Domain

public struct PileView: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: PileViewModel
    @State private var scene: PileScene?
    @State private var sceneSize: CGSize = .zero
    @State private var longPressTarget: BookID?

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
                    .init(id: Router.BoardMode.pile, title: "積読", badge: viewModel.books.count > 0 ? viewModel.books.count : nil)
                ],
                selection: Binding(get: { router.boardMode }, set: { router.boardMode = $0 })
            )
            stats
            if viewModel.display == .pile {
                pileScene
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

    private var pileScene: some View {
        GeometryReader { geo in
            let readyScene = sceneReady(preferredSize: geo.size)
            ZStack(alignment: .top) {
                SpriteView(scene: readyScene, options: [.allowsTransparency])
                    .frame(width: geo.size.width, height: geo.size.height)
                    .background(RoundedRectangle(cornerRadius: 14).fill(ColorToken.pileBackground))
                    .onChange(of: geo.size) { _, newSize in
                        if newSize != .zero { readyScene.size = newSize }
                    }
                    .onChange(of: viewModel.books) { _, _ in
                        updateScene(readyScene, initial: false)
                    }
                    .task {
                        // 初回表示時に 1 回だけ順次落下を実行
                        updateScene(readyScene, initial: true)
                    }

                Text("長押しで「読み始める」→ 本棚に貼られます")
                    .font(FontToken.caption())
                    .foregroundStyle(ColorToken.ink)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(ColorToken.ink.opacity(0.08)))
                    .padding(.top, 8)
            }
        }
    }

    /// シーンは View のライフタイム中に 1 回だけ生成し、以降はサイズだけ追従する。
    /// `.resizeFill` でも scene.size は自動更新されないため、サイズ変更は呼び出し側で設定する。
    /// body 中に @State を書くので DispatchQueue.main.async で次フレームへ繰り延べる。
    private func sceneReady(preferredSize: CGSize) -> PileScene {
        if let existing = scene {
            if preferredSize != .zero, existing.size != preferredSize {
                existing.size = preferredSize
            }
            return existing
        }
        let initial = preferredSize == .zero ? CGSize(width: 390, height: 500) : preferredSize
        let s = PileScene(size: initial)
        s.scaleMode = .resizeFill
        s.onTap = { id in router.detailBookID = id }
        s.onLongPress = { id in longPressTarget = id }
        DispatchQueue.main.async { scene = s }
        return s
    }

    private func updateScene(_ scene: PileScene, initial: Bool) {
        Task {
            let items: [PileScene.Item] = await mapToItems(viewModel.books)
            await MainActor.run {
                scene.update(items: items, initial: initial)
            }
        }
    }

    private func mapToItems(_ books: [Book]) async -> [PileScene.Item] {
        var out: [PileScene.Item] = []
        out.reserveCapacity(books.count)
        for book in books {
            // 向きは BookID から決定的に導出（Notion 01「縦:横 = 6:4」、reload で入れ替わらない）
            let firstByte = book.id.rawValue.uuid.0
            let orientation: PileScene.Orientation = (firstByte % 10) < 6 ? .vertical : .horizontal
            let data = (try? await container.coverImages.imageData(for: book.cover)) ?? nil
            out.append(.init(id: book.id, title: book.metadata.title, orientation: orientation, image: data.map(PileScene.SendableImageData.init)))
        }
        return out
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

#endif
