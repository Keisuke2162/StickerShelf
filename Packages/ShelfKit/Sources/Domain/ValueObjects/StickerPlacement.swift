public struct StickerPlacement: Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var rotationDegrees: Double
    public var scale: Double
    public var zIndex: Int

    public static let xRange: ClosedRange<Double> = 0.0...1.0
    public static let yRange: ClosedRange<Double> = 0.0...1.0
    public static let rotationRange: ClosedRange<Double> = -45.0...45.0
    public static let scaleRange: ClosedRange<Double> = 0.6...1.8

    public init(x: Double, y: Double, rotationDegrees: Double, scale: Double, zIndex: Int) {
        self.x = x.clamped(to: Self.xRange)
        self.y = y.clamped(to: Self.yRange)
        self.rotationDegrees = rotationDegrees.clamped(to: Self.rotationRange)
        self.scale = scale.clamped(to: Self.scaleRange)
        self.zIndex = zIndex
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
