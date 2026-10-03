import Foundation

/// Board の用途（本棚か積読か）。両者で ID 空間を共有し、Repository の fetchAll(kind:) で絞り込む。
public enum BoardKind: String, Hashable, Sendable, Codable, CaseIterable {
    case shelf
    case pile
}
