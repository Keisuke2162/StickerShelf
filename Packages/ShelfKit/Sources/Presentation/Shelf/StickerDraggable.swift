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

    private let baseSize = CGSize(width: 62, height: 90)

    var body: some View {
        let center = CGPoint(x: placement.x * boardSize.width, y: placement.y * boardSize.height)
        let currentScale = (placement.scale * magnify).clamped(to: StickerPlacement.scaleRange)
        let currentRotation = (placement.rotationDegrees + rotate.degrees).clamped(to: StickerPlacement.rotationRange)

        StickerView(
            cover: book.cover,
            title: book.metadata.title,
            edge: book.stickerEdge,
            size: baseSize,
            loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil }
        )
        .scaleEffect(currentScale * popScale)
        .rotationEffect(.degrees(currentRotation))
        .position(x: center.x + dragOffset.width, y: center.y + dragOffset.height)
        .onTapGesture {
            router.detailBookID = book.id
            Task { await viewModel.didTouchSticker(id: book.id) }
        }
        .contextMenu {
            Button("最前面へ") { Task { await viewModel.didTouchSticker(id: book.id) } }
            Button("積読に戻す") { Task { await viewModel.returnToPile(id: book.id) } }
            Button("削除", role: .destructive) { Task { await viewModel.deleteBook(id: book.id) } }
        }
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    let newCenter = CGPoint(x: center.x + value.translation.width, y: center.y + value.translation.height)
                    let normalized = StickerPlacement(
                        x: boardSize.width > 0 ? newCenter.x / boardSize.width : 0,
                        y: boardSize.height > 0 ? newCenter.y / boardSize.height : 0,
                        rotationDegrees: currentRotation,
                        scale: currentScale,
                        zIndex: placement.zIndex
                    )
                    Task { await viewModel.didEndGesture(id: book.id, placement: normalized) }
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .updating($magnify) { value, state, _ in
                    state = value.magnification
                }
                .onEnded { value in
                    let scale = (placement.scale * value.magnification).clamped(to: StickerPlacement.scaleRange)
                    let next = StickerPlacement(x: placement.x, y: placement.y, rotationDegrees: placement.rotationDegrees, scale: scale, zIndex: placement.zIndex)
                    Task { await viewModel.didEndGesture(id: book.id, placement: next) }
                }
        )
        .simultaneousGesture(
            RotateGesture()
                .updating($rotate) { value, state, _ in
                    state = value.rotation
                }
                .onEnded { value in
                    let deg = (placement.rotationDegrees + value.rotation.degrees).clamped(to: StickerPlacement.rotationRange)
                    let next = StickerPlacement(x: placement.x, y: placement.y, rotationDegrees: deg, scale: placement.scale, zIndex: placement.zIndex)
                    Task { await viewModel.didEndGesture(id: book.id, placement: next) }
                }
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
}

#endif
