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

    @State private var localPlacement: StickerPlacement?
    @State private var popScale: CGFloat = 1
    @State private var hasBroughtToFront = false
    @State private var showActionMenu = false

    /// 選択中かは ViewModel 経由（1 件のみ・空白タップで解除）。
    private var isSelected: Bool { viewModel.selectedStickerID == book.id }

    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var resizeMultiplier: Double = 1
    @GestureState private var rotateDelta: Angle = .zero
    @GestureState private var isPressing: Bool = false

    private let baseSize = CGSize(width: 62, height: 90)
    private let longPressDuration: Double = 0.1

    private var effectivePlacement: StickerPlacement { localPlacement ?? placement }

    private var liveScale: Double {
        (effectivePlacement.scale * resizeMultiplier).clamped(to: StickerPlacement.scaleRange)
    }
    private var liveRotation: Double {
        (effectivePlacement.rotationDegrees + rotateDelta.degrees).clamped(to: StickerPlacement.rotationRange)
    }

    var body: some View {
        let center = CGPoint(x: effectivePlacement.x * boardSize.width,
                             y: effectivePlacement.y * boardSize.height)
        let isGesturing = dragTranslation != .zero || resizeMultiplier != 1 || rotateDelta != .zero
        let scaledW = baseSize.width * liveScale
        let scaledH = baseSize.height * liveScale

        ZStack {
            StickerView(
                cover: book.cover,
                title: book.metadata.title,
                edge: book.stickerEdge,
                size: baseSize,
                loader: { cover in (try? await container.coverImages.imageData(for: cover)) ?? nil }
            )
            .scaleEffect(liveScale * (isGesturing || isPressing ? 1.05 : 1) * popScale)
            .rotationEffect(.degrees(liveRotation))
            .shadow(color: ColorToken.ink.opacity((isGesturing || isPressing) ? 0.3 : 0),
                    radius: (isGesturing || isPressing) ? 14 : 0,
                    y: (isGesturing || isPressing) ? 14 : 0)

            if isSelected {
                selectionOverlay(scaledSize: CGSize(width: scaledW, height: scaledH))
            }
        }
        .position(x: center.x + dragTranslation.width, y: center.y + dragTranslation.height)
        .onTapGesture {
            // 選択中は何もしない。選択解除はボード空白タップで行う（selectedStickerID = nil）。
            // 長押し成立直後にシステムが発火する暗黙のタップで選択を解除してしまうのを防ぐ意図もある。
            if !isSelected {
                router.detailBookID = book.id
            }
        }
        .gesture(moveGesture)
        // 2 本指ピンチ・回転は選択モードに関係なく常時有効（従来 UX の温存）。
        .simultaneousGesture(
            MagnifyGesture()
                .updating($resizeMultiplier) { value, state, _ in state = value.magnification }
                .onChanged { _ in bringToFrontOnce() }
                .onEnded { value in
                    persistEnd(translation: .zero, scaleMultiplier: value.magnification, rotation: .zero)
                }
        )
        .simultaneousGesture(
            RotateGesture()
                .updating($rotateDelta) { value, state, _ in state = value.rotation }
                .onChanged { _ in bringToFrontOnce() }
                .onEnded { value in
                    persistEnd(translation: .zero, scaleMultiplier: 1, rotation: value.rotation)
                }
        )
        .confirmationDialog("この本を", isPresented: $showActionMenu, titleVisibility: .hidden) {
            Button("最前面へ") { Task { await viewModel.didTouchSticker(id: book.id) } }
            Button("積読に戻す") { Task { await viewModel.returnToPile(id: book.id) } }
            Button("削除", role: .destructive) { Task { await viewModel.deleteBook(id: book.id) } }
            Button("キャンセル", role: .cancel) {}
        }
        .onChange(of: isPressing) { _, newValue in
            // 長押し成立の瞬間（isPressing が false→true）に選択モードへ入る。
            // ドラッグ移動しないと .onChanged が発火しないパスがあるため、@GestureState の変化で捕捉する。
            if newValue, !isSelected {
                viewModel.selectedStickerID = book.id
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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

    // MARK: - Selection overlay

    @ViewBuilder
    private func selectionOverlay(scaledSize: CGSize) -> some View {
        let framePadding: CGFloat = 6
        let frameW = scaledSize.width + framePadding * 2
        let frameH = scaledSize.height + framePadding * 2

        ZStack {
            Rectangle()
                .strokeBorder(ColorToken.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(width: frameW, height: frameH)
                .allowsHitTesting(false)

            // 右下隅の統合ハンドル。ドラッグで scale + rotation を同時に更新する。
            handleCircle()
                .overlay(
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ColorToken.accent)
                )
                .offset(x: frameW / 2, y: frameH / 2)
                .gesture(transformGesture())

            // メニューボタン（枠の左上の外側）
            Button {
                showActionMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(ColorToken.accent))
                    .shadow(color: ColorToken.ink.opacity(0.2), radius: 2)
            }
            .buttonStyle(.plain)
            .offset(x: -(frameW / 2) - 20, y: -(frameH / 2) - 20)
        }
        .rotationEffect(.degrees(liveRotation))
    }

    private func handleCircle() -> some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(ColorToken.accent, lineWidth: 2))
            .frame(width: 22, height: 22)
            .shadow(color: ColorToken.ink.opacity(0.25), radius: 2, y: 1)
    }

    // MARK: - Gestures

    /// 長押し → ドラッグ。長押しで選択モード突入、選択中はドラッグで移動保存。
    private var moveGesture: some Gesture {
        LongPressGesture(minimumDuration: longPressDuration)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($isPressing) { value, state, _ in
                if case .second(let longPressed, _) = value { state = longPressed }
            }
            .updating($dragTranslation) { value, state, _ in
                // 選択モード突入時の長押しだけの瞬間ではドラッグ移動させず、
                // isSelected == true 以降のドラッグ translation だけ反映する。
                if case .second(true, let drag?) = value, isSelected {
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
                if distance >= 4 {
                    persistEnd(translation: translation, scaleMultiplier: 1, rotation: .zero)
                }
            }
    }

    /// 右下隅の統合ハンドル。中心→開始位置と中心→現在位置の
    /// 「距離の比」で scale、「角度の差」で rotation を同時に更新する。
    /// ボード座標固定で、書影自身の回転の影響を受けない。
    private func transformGesture() -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("stickerBoard"))
            .updating($resizeMultiplier) { value, state, _ in
                state = Self.transformMultiplier(startLocation: value.startLocation,
                                                 location: value.location,
                                                 centerOnBoard: centerOnBoard())
            }
            .updating($rotateDelta) { value, state, _ in
                state = Self.transformRotation(startLocation: value.startLocation,
                                               location: value.location,
                                               centerOnBoard: centerOnBoard())
            }
            .onChanged { _ in bringToFrontOnce() }
            .onEnded { value in
                let m = Self.transformMultiplier(startLocation: value.startLocation,
                                                 location: value.location,
                                                 centerOnBoard: centerOnBoard())
                let r = Self.transformRotation(startLocation: value.startLocation,
                                               location: value.location,
                                               centerOnBoard: centerOnBoard())
                persistEnd(translation: .zero, scaleMultiplier: m, rotation: r)
            }
    }

    /// 書影中心のボード座標。
    private func centerOnBoard() -> CGPoint {
        CGPoint(x: effectivePlacement.x * boardSize.width,
                y: effectivePlacement.y * boardSize.height)
    }

    private static func transformMultiplier(startLocation: CGPoint, location: CGPoint, centerOnBoard: CGPoint) -> Double {
        let startDist = hypot(Double(startLocation.x - centerOnBoard.x),
                              Double(startLocation.y - centerOnBoard.y))
        let currDist = hypot(Double(location.x - centerOnBoard.x),
                             Double(location.y - centerOnBoard.y))
        guard startDist > 1 else { return 1 }  // ハンドル極近接時のゼロ除算回避
        return max(0.05, currDist / startDist)
    }

    private static func transformRotation(startLocation: CGPoint, location: CGPoint, centerOnBoard: CGPoint) -> Angle {
        let a0 = atan2(Double(startLocation.x - centerOnBoard.x), -Double(startLocation.y - centerOnBoard.y))
        let a1 = atan2(Double(location.x - centerOnBoard.x), -Double(location.y - centerOnBoard.y))
        var deltaDeg = (a1 - a0) * 180 / .pi
        while deltaDeg > 180 { deltaDeg -= 360 }
        while deltaDeg < -180 { deltaDeg += 360 }
        return .degrees(deltaDeg)
    }

    // MARK: - Side effects

    private func bringToFrontOnce() {
        guard !hasBroughtToFront else { return }
        hasBroughtToFront = true
        Task { await viewModel.didTouchSticker(id: book.id) }
    }

    private func persistEnd(translation: CGSize, scaleMultiplier: Double, rotation: Angle) {
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
        let nextScale = (base.scale * scaleMultiplier).clamped(to: StickerPlacement.scaleRange)
        let nextRotation = (base.rotationDegrees + rotation.degrees).clamped(to: StickerPlacement.rotationRange)
        let next = StickerPlacement(x: nextX, y: nextY, rotationDegrees: nextRotation, scale: nextScale, zIndex: base.zIndex)
        localPlacement = next
        hasBroughtToFront = false
        Task { await viewModel.didEndGesture(id: book.id, placement: next) }
    }
}

#endif
