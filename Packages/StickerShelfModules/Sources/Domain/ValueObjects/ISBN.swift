import Foundation

/// ISBN-13 に正規化した値オブジェクト。ISBN-10 は 978 プレフィックスを付けて 13 桁へ変換する。
public struct ISBN: Hashable, Sendable, Codable {
    public let value: String

    public init?(_ raw: String) {
        let digits = raw.filter { $0.isNumber || $0 == "X" || $0 == "x" }
            .uppercased()
        switch digits.count {
        case 13:
            guard digits.allSatisfy({ $0.isNumber }) else { return nil }
            guard ISBN.isValidISBN13(digits) else { return nil }
            self.value = digits
        case 10:
            guard ISBN.isValidISBN10(digits) else { return nil }
            self.value = ISBN.convertTo13(digits)
        default:
            return nil
        }
    }

    private static func isValidISBN10(_ s: String) -> Bool {
        guard s.count == 10 else { return false }
        var sum = 0
        for (i, ch) in s.enumerated() {
            let weight = 10 - i
            let digit: Int
            if ch == "X", i == 9 {
                digit = 10
            } else if let d = ch.wholeNumberValue {
                digit = d
            } else {
                return false
            }
            sum += weight * digit
        }
        return sum % 11 == 0
    }

    private static func isValidISBN13(_ s: String) -> Bool {
        guard s.count == 13 else { return false }
        var sum = 0
        for (i, ch) in s.enumerated() {
            guard let d = ch.wholeNumberValue else { return false }
            sum += (i % 2 == 0 ? d : d * 3)
        }
        return sum % 10 == 0
    }

    private static func convertTo13(_ isbn10: String) -> String {
        let base = "978" + String(isbn10.prefix(9))
        var sum = 0
        for (i, ch) in base.enumerated() {
            let d = ch.wholeNumberValue ?? 0
            sum += (i % 2 == 0 ? d : d * 3)
        }
        let check = (10 - sum % 10) % 10
        return base + String(check)
    }
}
