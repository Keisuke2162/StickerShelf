import Testing
@testable import Domain

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Suite("StickerPlacementFactory")
struct StickerPlacementFactoryTests {
    @Test func zIndexIsMaxPlusOne() {
        let factory = StickerPlacementFactory()
        var rng = SeededRNG(seed: 42)
        let placement = factory.make(existingZIndexes: [1, 3, 5], using: &rng)
        #expect(placement.zIndex == 6)
    }

    @Test func zIndexIsOneWhenEmpty() {
        let factory = StickerPlacementFactory()
        var rng = SeededRNG(seed: 42)
        let placement = factory.make(existingZIndexes: [], using: &rng)
        #expect(placement.zIndex == 1)
    }

    @Test func withinRanges() {
        let factory = StickerPlacementFactory()
        var rng = SeededRNG(seed: 123)
        for _ in 0..<20 {
            let p = factory.make(existingZIndexes: [], using: &rng)
            #expect((0.2...0.8).contains(p.x))
            #expect((0.2...0.75).contains(p.y))
            #expect((-12.0...12.0).contains(p.rotationDegrees))
            #expect(p.scale == 1.0)
        }
    }
}
