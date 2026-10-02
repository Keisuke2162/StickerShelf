import Foundation

/// 新規ステッカーのランダム配置を生成する。
public struct StickerPlacementFactory: Sendable {
    public struct Ranges: Sendable {
        public var x: ClosedRange<Double>
        public var y: ClosedRange<Double>
        public var rotation: ClosedRange<Double>
        public var scale: Double

        public init(
            x: ClosedRange<Double> = 0.2...0.8,
            y: ClosedRange<Double> = 0.2...0.75,
            rotation: ClosedRange<Double> = -12...12,
            scale: Double = 1.0
        ) {
            self.x = x
            self.y = y
            self.rotation = rotation
            self.scale = scale
        }
    }

    public let ranges: Ranges

    public init(ranges: Ranges = Ranges()) {
        self.ranges = ranges
    }

    public func make(existingZIndexes: [Int], using rng: inout some RandomNumberGenerator) -> StickerPlacement {
        let z = (existingZIndexes.max() ?? 0) + 1
        return StickerPlacement(
            x: Double.random(in: ranges.x, using: &rng),
            y: Double.random(in: ranges.y, using: &rng),
            rotationDegrees: Double.random(in: ranges.rotation, using: &rng),
            scale: ranges.scale,
            zIndex: z
        )
    }

    /// システム乱数を使う簡易呼び出し。
    public func make(existingZIndexes: [Int]) -> StickerPlacement {
        var rng = SystemRandomNumberGenerator()
        return make(existingZIndexes: existingZIndexes, using: &rng)
    }
}
