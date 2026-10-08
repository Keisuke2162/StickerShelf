#if canImport(UIKit)
import Foundation

/// アプリ共通の yyyy/MM/dd 表示フォーマット。`Text(date, format: .yyyyMMddSlash)` で使う。
extension FormatStyle where Self == Date.FormatStyle {
    static var yyyyMMddSlash: Date.FormatStyle {
        Date.FormatStyle(date: .numeric, time: .omitted)
            .locale(Locale(identifier: "ja_JP"))
    }
}

#endif
