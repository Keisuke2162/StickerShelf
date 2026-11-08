import Foundation
import Domain

public protocol BringStickerToFrontUseCaseProtocol: Sendable {
    func execute(id: BookID) async throws
}

public struct BringStickerToFrontUseCase: BringStickerToFrontUseCaseProtocol {
    public static let compactionThreshold = 10_000

    private let books: BookRepository

    public init(books: BookRepository) {
        self.books = books
    }

    public func execute(id: BookID) async throws {
        var onShelf = try await books.fetch(status: [.reading, .finished])
        guard let targetIndex = onShelf.firstIndex(where: { $0.id == id }), var target = onShelf.first(where: { $0.id == id }) else {
            return
        }
        let maxZ = onShelf.compactMap(\.sticker).map(\.zIndex).max() ?? 0
        guard let placement = target.sticker else { return }

        if maxZ + 1 > Self.compactionThreshold {
            // 全体を addedAt 昇順で詰め直し、target を最前面に。
            onShelf.sort { $0.addedAt < $1.addedAt }
            var next = 1
            for i in onShelf.indices {
                if onShelf[i].id == id { continue }
                if let sticker = onShelf[i].sticker {
                    let newPlacement = StickerPlacement(
                        x: sticker.x,
                        y: sticker.y,
                        rotationDegrees: sticker.rotationDegrees,
                        scale: sticker.scale,
                        zIndex: next
                    )
                    try onShelf[i].moveSticker(to: newPlacement)
                    next += 1
                }
            }
            let newTargetPlacement = StickerPlacement(
                x: placement.x,
                y: placement.y,
                rotationDegrees: placement.rotationDegrees,
                scale: placement.scale,
                zIndex: next
            )
            try target.moveSticker(to: newTargetPlacement)
            onShelf[targetIndex] = target
            try await books.saveAll(onShelf)
        } else {
            let newPlacement = StickerPlacement(
                x: placement.x,
                y: placement.y,
                rotationDegrees: placement.rotationDegrees,
                scale: placement.scale,
                zIndex: maxZ + 1
            )
            try target.moveSticker(to: newPlacement)
            try await books.save(target)
        }
    }
}
