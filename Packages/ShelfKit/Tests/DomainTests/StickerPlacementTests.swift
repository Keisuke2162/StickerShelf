import Testing
@testable import Domain

@Suite("StickerPlacement の clamp")
struct StickerPlacementTests {
    @Test func clampsOutOfRange() {
        let p = StickerPlacement(x: 1.5, y: -0.5, rotationDegrees: 99, scale: 2.5, zIndex: 10)
        #expect(p.x == 1.0)
        #expect(p.y == 0.0)
        #expect(p.rotationDegrees == 45.0)
        #expect(p.scale == 1.8)
        #expect(p.zIndex == 10)
    }

    @Test func keepsInRange() {
        let p = StickerPlacement(x: 0.3, y: 0.6, rotationDegrees: -12, scale: 1.1, zIndex: 3)
        #expect(p.x == 0.3)
        #expect(p.y == 0.6)
        #expect(p.rotationDegrees == -12)
        #expect(p.scale == 1.1)
    }
}
