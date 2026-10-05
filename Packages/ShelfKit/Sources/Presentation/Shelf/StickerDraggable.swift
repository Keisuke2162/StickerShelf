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

    /// 長押し成功後の DragGesture.translation。長押し前・ドラッグなしのときは .zero。
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var magnify: CGFloat = 1
    @GestureState private var rotate: Angle = .zero
    /// 長押しに成功して「持ち上げ」状態になっているか。表示演出（1.05倍・影）に使う。
    @GestureState private var isLifted: Bool = false
    @State private var popScale: CGFloat = 1
    @State private var hasBroughtToFront = false
    @State private var showActionMenu = false
    @State private var localPlacement: StickerPlacement?

    private let baseSize = CGSize(width: 62, height: 90)
    private let longPressDuration: Double = 0.15

    private var effectivePlacement: StickerPlacement { localPlacement ?? placement }

    var body: some View {
        let center = CGPoint(x: effectivePlacement.x * boardSize.width, y: effectivePlacement.y * boardSize.height)
        let isMoving = isLifted || magnify != 1 || rotate != .zero
        let liveScale = (effectivePlacement.scale * magnify).clamped(to: StickerPlacement.scaleRange)
        let liveRotation = (effectivePlacement.rotationDegrees + rotate.degrees).clamped(to: StickerPlacement.rotationRange)

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
        .position(x: center.x + dragTranslation.width, y: center.y + dragTranslation.height)
        .onTapGesture {
            router.detailBookID = book.id
        }
        // 長押し → ドラッグの sequence。長押しに達するまでドラッグは発火しない。
        // ドラッグに移行しなかった（≒ほぼ動かさず離した）場合は confirmationDialog を出す。
        .gesture(
            LongPressGesture(minimumDuration: longPressDuration)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .updating($isLifted) { value, state, _ in
                    switch value {
                    case .first:
                        state = false
                    case .second(let longPressed, _):
                        state = longPressed
                    }
                }
                .updating($dragTranslation) { value, state, _ in
                    if case .second(true, let drag?) = value {
                        state = drag.translation
                    }
                }
                .onChanged { value in
                    if case .second(true, _) = value {
                        bringToFrontOnce()
                    }
                }
                .onEnded { value in
                    guard case .second(true, let drag) = value else { return }
                    let translation = drag?.translation ?? .zero
                    let distance = hypot(translation.width, translation.height)
                    if distance < 4 {
                        // 長押ししたが動かさなかった → アクションメニュー
                        showActionMenu = true
                        hasBroughtToFront = false
                    } else {
                        persistEnd(translation: translation, magnification: 1, rotation: .zero)
                    }
                }
        )
        // ピンチ・回転は 2 本指なので長押し不要。従来どおり同時成立。
        .simultaneousGesture(
            MagnifyGesture()
                .updating($magnify) { value, state, _ in
                    state = value.magnification
                }
                .onChanged { _ in bringToFrontOnce() }
                .onEnded { value in
                    persistEnd(translation: .zero, magnification: value.magnification, rotation: .zero)
                }
        )
        .simultaneousGesture(
            RotateGesture()
                .updating($rotate) { value, state, _ in
                    state = value.rotation
                }
                .onChanged { _ in bringToFrontOnce() }
                .onEnded { value in
                    persistEnd(translation: .zero, magnification: 1, rotation: value.rotation)
                }
        )
        .confirmationDialog("この本を", isPresented: $showActionMenu, titleVisibility: .hidden) {
            Button("最前面へ") { Task { await viewModel.didTouchSticker(id: book.id) } }
            Button("積読に戻す") { Task { await viewModel.returnToPile(id: book.id) } }
            Button("削除", role: .destructive) { Task { await viewModel.deleteBook(id: book.id) } }
            Button("キャンセル", role: .cancel) {}
        }
        .onChange(of: isLifted) { _, newValue in
            if newValue {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                bringToFrontOnce()
            }
        }
        .onChange(of: placement) { _, newValue in
            if let local = localPlacement, local == newValue {
                localPlacement = nil
            }
        }
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

    private func persistEnd(translation: CGSize, magnification: CGFloat, rotation: Angle) {
        let base = effectivePlacement
        let nextX: Double
        let nextY: Double
        if boardSize.width > 0, boardSize.height > 0 {
            let xBase = base.x * boardSize.width
            let yBase = base.y * boardSize.height
            nextX = ((xBase + translation.width) / boardSize.width).clamped(to: StickerPlacement.xRange)
            nextY = ((yBase + translation.height) / boardSize.height).clamped(to: StickerPlacement.yRange)
        } else {
            nextX = base.x
            nextY = base.y
        }
        let nextScale = (base.scale * magnification).clamped(to: StickerPlacement.scaleRange)
        let nextRotation = (base.rotationDegrees + rotation.degrees).clamped(to: StickerPlacement.rotationRange)
        let next = StickerPlacement(x: nextX, y: nextY, rotationDegrees: nextRotation, scale: nextScale, zIndex: base.zIndex)
        localPlacement = next
        hasBroughtToFront = false
        Task { await viewModel.didEndGesture(id: book.id, placement: next) }
    }
}

#endif
