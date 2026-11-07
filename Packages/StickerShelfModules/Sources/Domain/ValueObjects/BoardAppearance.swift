import Foundation

/// 本棚ボードの背景色プリセット。SwiftUI の Color への変換は Presentation 層で行う。
public enum BoardColor: String, Hashable, Sendable, Codable, CaseIterable {
    case cream
    case mint
    case sky
    case lavender
    case rose
    case sand

    public var displayName: String {
        switch self {
        case .cream: return "クリーム"
        case .mint: return "ミント"
        case .sky: return "スカイ"
        case .lavender: return "ラベンダー"
        case .rose: return "ローズ"
        case .sand: return "サンド"
        }
    }
}

/// 本棚ボードの背景模様プリセット。
public enum BoardPattern: String, Hashable, Sendable, Codable, CaseIterable {
    case dots
    case grid
    case plain
    case stripes

    public var displayName: String {
        switch self {
        case .dots: return "ドット"
        case .grid: return "方眼"
        case .plain: return "無地"
        case .stripes: return "ストライプ"
        }
    }
}

/// ボードの見た目設定。
public struct BoardAppearance: Hashable, Sendable, Codable {
    public var color: BoardColor
    public var pattern: BoardPattern

    public init(color: BoardColor = .cream, pattern: BoardPattern = .dots) {
        self.color = color
        self.pattern = pattern
    }

    public static let `default` = BoardAppearance()
}
