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
            if isSelected {
                viewModel.selectedStickerID = nil
            } else {
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
        let rotateHandleGap: CGFloat = 28

        ZStack {
            Rectangle()
                .strokeBorder(ColorToken.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(width: frameW, height: frameH)
                .allowsHitTesting(false)

            // 回転ハンドル（上部）
            handleCircle()
                .offset(x: 0, y: -(frameH / 2) - rotateHandleGap)
                .gesture(rotateGesture(frameHeight: frameH, handleGap: rotateHandleGap))

            // 回転ハンドルから枠まで繋ぐ短い線
            Rectangle()
                .fill(ColorToken.accent)
                .frame(width: 1.5, height: rotateHandleGap)
                .offset(x: 0, y: -(frameH / 2) - rotateHandleGap / 2)
                .allowsHitTesting(false)

            // 四隅のハンドル。四隅どれでも対角方向のドラッグで拡縮できる。
            cornerHandle(dx: -frameW / 2, dy: -frameH / 2, sign: -1) // 左上
            cornerHandle(dx:  frameW / 2, dy: -frameH / 2, sign: +1) // 右上は +x,-y → combined 使い方調整するより、同じ formula を使う
            cornerHandle(dx: -frameW / 2, dy:  frameH / 2, sign: +1)
            cornerHandle(dx:  frameW / 2, dy:  frameH / 2, sign: +1) // 右下
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

    private func cornerHandle(dx: CGFloat, dy: CGFloat, sign: CGFloat) -> some View {
        handleCircle()
            .offset(x: dx, y: dy)
            .gesture(resizeGesture(cornerDx: dx, cornerDy: dy))
    }

    private func handleCircle() -> some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(ColorToken.accent, lineWidth: 2))
            .frame(width: 18, height: 18)
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
                    if !isSelected {
                        viewModel.selectedStickerID = book.id
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
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

    /// 四隅ハンドルのドラッグ → 中心を基準にスケール変更。
    /// 各ハンドルの対角方向（中心からハンドルへのベクトル）に沿った成分だけを拡縮量に反映。
    private func resizeGesture(cornerDx: CGFloat, cornerDy: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($resizeMultiplier) { value, state, _ in
                state = Self.resizeMultiplier(from: value.translation,
                                              cornerDx: cornerDx, cornerDy: cornerDy,
                                              rotationDegrees: effectivePlacement.rotationDegrees)
            }
            .onChanged { _ in bringToFrontOnce() }
            .onEnded { value in
                let m = Self.resizeMultiplier(from: value.translation,
                                              cornerDx: cornerDx, cornerDy: cornerDy,
                                              rotationDegrees: effectivePlacement.rotationDegrees)
                persistEnd(translation: .zero, scaleMultiplier: m, rotation: .zero)
            }
    }

    private static func resizeMultiplier(from translation: CGSize,
                                         cornerDx: CGFloat, cornerDy: CGFloat,
                                         rotationDegrees: Double) -> Double {
        // 親の .rotationEffect 下では DragGesture の translation は既に view のローカル座標系で返るので、
        // 追加の逆回転補正は不要。そのまま「中心→ハンドル」方向への成分を取る。
        let len = sqrt(cornerDx * cornerDx + cornerDy * cornerDy)
        guard len > 0 else { return 1 }
        let ux = cornerDx / len
        let uy = cornerDy / len
        let along = Double(translation.width) * Double(ux) + Double(translation.height) * Double(uy)
        let m = (Double(len) + along) / Double(len)
        return max(0.05, m)
    }

    /// 回転ハンドルのドラッグ → 中心軸での回転角を計算。
    /// 書影ローカル座標（.rotationEffect 下）だとドラッグ中に書影自身が回転するたびに
    /// translation の座標系が変わり挙動が暴れるため、ボード座標系に固定して
    /// startLocation と現在 location から中心基準の角度差分を直接計算する。
    private func rotateGesture(frameHeight: CGFloat, handleGap: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("stickerBoard"))
            .updating($rotateDelta) { value, state, _ in
                state = Self.rotateDelta(startLocation: value.startLocation,
                                         location: value.location,
                                         centerOnBoard: centerOnBoard())
            }
            .onChanged { _ in bringToFrontOnce() }
            .onEnded { value in
                let d = Self.rotateDelta(startLocation: value.startLocation,
                                         location: value.location,
                                         centerOnBoard: centerOnBoard())
                persistEnd(translation: .zero, scaleMultiplier: 1, rotation: d)
            }
    }

    /// 書影中心のボード座標。
    private func centerOnBoard() -> CGPoint {
        CGPoint(x: effectivePlacement.x * boardSize.width,
                y: effectivePlacement.y * boardSize.height)
    }

    private static func rotateDelta(startLocation: CGPoint, location: CGPoint, centerOnBoard: CGPoint) -> Angle {
        // ボード座標系の中心→開始位置の角度と、中心→現在位置の角度の差分がそのまま回転量。
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
