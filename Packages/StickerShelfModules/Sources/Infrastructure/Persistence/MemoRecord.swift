import Foundation
import SwiftData

/// SwiftData に永続化する「気になる本のタイトルメモ」1 レコード。
@Model
public final class MemoRecord {
    @Attribute(.unique) public var id: UUID = UUID()
    public var title: String = ""
    public var createdAt: Date = Date(timeIntervalSince1970: 0)

    public init(id: UUID, title: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
