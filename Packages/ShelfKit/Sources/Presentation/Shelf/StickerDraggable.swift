#if canImport(UIKit)
import SwiftUI
import Domain

struct StickerDraggable: View {
    let book: Book
    let placement: StickerPlacement
    let boardSize: CGSize
    let viewModel: ShelfViewModel
    let router: Router
    let container: PresentationContainer

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var magnify: CGFloat = 1
    @GestureState private var rotate: Angle = .zero
    @State private var popScale: CGFloat = 1
    @State private var hasBroughtToFront = false
    @State private var isActivelyGesturing = false

    private let baseSize = CGSize(width: 62, height: 90)

    /// 現在ジェスチャ中の派生値を含めた最新の placement。
    private var liveX: Double {
        guard boardSize.width > 0 else { return placement.x }
        let base = placement.x * boardSize.width
        return ((base + dragOffset.width) / boardSize.width).clamped(to: StickerPlacement.xRange)
    }
    private var liveY: Double {
        guard boardSize.height > 0 else { return placement.y }
        let base = placement.y * boardSize.height
        return ((base + dragOffset.height) / boardSize.height).clamped(to: StickerPlacement.yRange)
    }
    private var liveScale: Double {
        (placement.scale * magnify).clamped(to: StickerPlacement.scaleRange)
    }
    private var liveRotation: Double {
        (placement.rotationDegrees + rotate.degrees).clamped(to: StickerPlacement.rotationRange)
    }

    var body: some View {
        let center = CGPoint(x: placement.x * boardSize.width, y: placement.y * boardSize.height)
        let isMoving = dragOffset != .zero || magnify != 1 || rotate != .zero

        StickerView(
            cover: book.cover,
            title: book.metadata.title,
            edge: book.stickerEdge,
            size: baseSize,
            loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil }
        )
        .scaleEffect((isMoving ? liveScale * 1.05 : liveScale) * popScale)
        .rotationEffect(.degrees(liveRotation))
        .shadow(color: ColorToken.ink.opacity(isMoving ? 0.3 : 0), radius: isMoving ? 14 : 0, y: isMoving ? 14 : 0)
        .position(x: center.x + dragOffset.width, y: center.y + dragOffset.height)
        .onTapGesture {
            router.detailBookID = book.id
        }
        .contextMenu {
            Button("最前面へ") { Task { await viewModel.didTouchSticker(id: book.id) } }
            Button("積読に戻す") { Task { await viewModel.returnToPile(id: book.id) } }
            Button("削除", role: .destructive) { Task { await viewModel.deleteBook(id: book.id) } }
        }
        // ドラッグは「指が 4pt 以上動いたら」発火。これより小さい動きは onTapGesture が拾う。
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onChanged { _ in bringToFrontOnce() }
                .onEnded { _ in
                    persistCurrent()
                }
        )
        // ピンチ・回転は 2 本指なのでドラッグと競合しない。.simultaneousGesture で同時成立。
        .simultaneousGesture(
            MagnifyGesture()
                .updating($magnify) { value, state, _ in
                    state = value.magnification
                }
                .onChanged { _ in bringToFrontOnce() }
                .onEnded { _ in persistCurrent() }
        )
        .simultaneousGesture(
            RotateGesture()
                .updating($rotate) { value, state, _ in
                    state = value.rotation
                }
                .onChanged { _ in bringToFrontOnce() }
                .onEnded { _ in persistCurrent() }
        )
        .onAppear {
            if viewModel.popAnimationIDs.contains(book.id) && !UIAccessibility.isReduceMotionEnabled {
                popScale = 1.3
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    popScale = 1.0
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.clearPopAnimation(id: book.id)
            }
        }
    }

    private func bringToFrontOnce() {
        guard !hasBroughtToFront else { return }
        hasBroughtToFront = true
        Task { await viewModel.didTouchSticker(id: book.id) }
    }

    private func persistCurrent() {
        let next = StickerPlacement(
            x: liveX, y: liveY,
            rotationDegrees: liveRotation,
            scale: liveScale,
            zIndex: placement.zIndex
        )
        hasBroughtToFront = false
        Task { await viewModel.didEndGesture(id: book.id, placement: next) }
    }
}

#endif
