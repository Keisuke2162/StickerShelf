import Foundation
import SwiftData

/// ユーザー定義の本棚ボード。
@Model
public final class BoardRecord {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var createdAt: Date = Date(timeIntervalSince1970: 0)
    public var sortOrder: Int = 0

    public init(id: UUID, name: String, createdAt: Date, sortOrder: Int) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}
