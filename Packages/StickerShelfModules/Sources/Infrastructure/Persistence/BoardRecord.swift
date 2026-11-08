import Foundation
import SwiftData

/// ユーザー定義のフォルダ（本棚ボード または 積読フォルダ）。
///
/// `kindRaw` のデフォルトは "shelf"、`appearanceColorRaw` / `appearancePatternRaw` のデフォルトは
/// 既定の「クリーム / ドット」。既存ストアからマイグレートしても自然な既定値になる。
@Model
public final class BoardRecord {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var createdAt: Date = Date(timeIntervalSince1970: 0)
    public var sortOrder: Int = 0
    public var kindRaw: String = "shelf"
    public var appearanceColorRaw: String = "cream"
    public var appearancePatternRaw: String = "dots"

    public init(id: UUID,
                name: String,
                createdAt: Date,
                sortOrder: Int,
                kindRaw: String = "shelf",
                appearanceColorRaw: String = "cream",
                appearancePatternRaw: String = "dots") {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.kindRaw = kindRaw
        self.appearanceColorRaw = appearanceColorRaw
        self.appearancePatternRaw = appearancePatternRaw
    }
}
