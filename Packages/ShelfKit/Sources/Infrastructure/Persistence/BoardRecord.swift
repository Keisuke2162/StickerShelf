import Foundation
import SwiftData

/// ユーザー定義のフォルダ（本棚ボード または 積読フォルダ）。
///
/// `kindRaw` のデフォルトは "shelf"。既存ストア（kind カラム未保有）からマイグレートした場合は
/// 全レコードが .shelf として解釈される。
@Model
public final class BoardRecord {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var createdAt: Date = Date(timeIntervalSince1970: 0)
    public var sortOrder: Int = 0
    public var kindRaw: String = "shelf"

    public init(id: UUID, name: String, createdAt: Date, sortOrder: Int, kindRaw: String = "shelf") {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.kindRaw = kindRaw
    }
}
