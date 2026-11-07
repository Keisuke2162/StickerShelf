/// ステッカーの正規化位置・回転・拡大率・重なり順。
///
/// `x`/`y` は 0.0...1.0（ステッカー中心の正規化座標、ボード幅・高さに対する比率）。
/// `rotationDegrees` は -180.0...180.0、`scale` は 0.4...3.0 ――「シール帳のように自由に貼る」
/// 楽しさを優先し Notion 03 の既定範囲（±45° / 0.6〜1.8）より広げてある（2026-10-04 判断、DECISIONS 参照）。
/// init で範囲外の値は **silently clamp** する。
/// 永続層からの復元時に保存値が異常なら復元位置が動く点に注意する（Mapper 側で検証するか、
/// 保存前に Domain を通して正規化しておくこと）。
public struct StickerPlacement: Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var rotationDegrees: Double
    public var scale: Double
    public var zIndex: Int

    public static let xRange: ClosedRange<Double> = 0.0...1.0
    public static let yRange: ClosedRange<Double> = 0.0...1.0
    public static let rotationRange: ClosedRange<Double> = -180.0...180.0
    public static let scaleRange: ClosedRange<Double> = 0.4...3.0

    public init(x: Double, y: Double, rotationDegrees: Double, scale: Double, zIndex: Int) {
        self.x = x.clamped(to: Self.xRange)
        self.y = y.clamped(to: Self.yRange)
        self.rotationDegrees = rotationDegrees.clamped(to: Self.rotationRange)
        self.scale = scale.clamped(to: Self.scaleRange)
        self.zIndex = zIndex
    }
}

public extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
