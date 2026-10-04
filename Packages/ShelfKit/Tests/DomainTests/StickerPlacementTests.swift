import Testing
@testable import Domain

@Suite("StickerPlacement の clamp")
struct StickerPlacementTests {
    @Test func clampsOutOfRange() {
        // 2026-10-04: 「シール帳のように自由に貼る」ため rotation ±180° / scale 0.4〜3.0 に拡張。
        let p = StickerPlacement(x: 1.5, y: -0.5, rotationDegrees: 999, scale: 5.0, zIndex: 10)
        #expect(p.x == 1.0)
        #expect(p.y == 0.0)
        #expect(p.rotationDegrees == 180.0)
        #expect(p.scale == 3.0)
        #expect(p.zIndex == 10)
    }

    @Test func clampsBelowLowerBounds() {
        let p = StickerPlacement(x: -0.2, y: 2.0, rotationDegrees: -999, scale: 0.1, zIndex: 0)
        #expect(p.x == 0.0)
        #expect(p.y == 1.0)
        #expect(p.rotationDegrees == -180.0)
        #expect(p.scale == 0.4)
    }

    @Test func keepsInRange() {
        let p = StickerPlacement(x: 0.3, y: 0.6, rotationDegrees: -12, scale: 1.1, zIndex: 3)
        #expect(p.x == 0.3)
        #expect(p.y == 0.6)
        #expect(p.rotationDegrees == -12)
        #expect(p.scale == 1.1)
    }
}
