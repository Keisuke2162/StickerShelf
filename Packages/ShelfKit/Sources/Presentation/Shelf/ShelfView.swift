#if canImport(UIKit)
import SwiftUI
import Domain

public struct ShelfView: View {
    private let container: PresentationContainer
    private let router: Router
    @State private var viewModel: ShelfViewModel

    public init(container: PresentationContainer, router: Router) {
        self.container = container
        self.router = router
        self._viewModel = State(initialValue: ShelfViewModel(container: container))
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            segment
            filterChips
            board
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorToken.boardBackground.ignoresSafeArea())
        .task { await viewModel.reload() }
        .task(id: router.boardMode) {
            if router.boardMode == .shelf { await viewModel.start() }
        }
    }

    private var header: some View {
        HStack {
            Text("本棚")
                .font(FontToken.screenTitle())
                .foregroundStyle(ColorToken.ink)
            Spacer()
        }
    }

    private var segment: some View {
        SegmentedSwitch(
            options: [
                .init(id: Router.BoardMode.shelf, title: "本棚 \(viewModel.countReading + viewModel.countFinished)"),
                .init(id: Router.BoardMode.pile, title: "積読", badge: viewModel.countUnread > 0 ? viewModel.countUnread : nil)
            ],
            selection: Binding(
                get: { router.boardMode },
                set: { router.boardMode = $0 }
            )
        )
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            Chip(title: "すべて", isSelected: viewModel.filter == .all) { viewModel.filter = .all }
            Chip(title: "読んでる \(viewModel.countReading)", isSelected: viewModel.filter == .readingOnly) { viewModel.filter = .readingOnly }
            Chip(title: "読んだ \(viewModel.countFinished)", isSelected: viewModel.filter == .finishedOnly) { viewModel.filter = .finishedOnly }
            Spacer()
        }
    }

    private var board: some View {
        GeometryReader { geo in
            ZStack {
                DotGridBackground()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewModel.books.isEmpty && !viewModel.isLoading {
                    EmptyShelfPlaceholder {
                        router.boardMode = .pile
                    } onAdd: {
                        router.isAddingBook = true
                    }
                }

                ForEach(viewModel.books.sorted(by: { ($0.sticker?.zIndex ?? 0) < ($1.sticker?.zIndex ?? 0) })) { book in
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
        .background(RoundedRectangle(cornerRadius: 14).fill(ColorToken.boardBackground))
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
                Button("＋ 追加", action: onAdd)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

#endif
