import Testing
@testable import Domain

@Suite("ISBN 値オブジェクト")
struct ISBNTests {
    @Test func valid13() {
        #expect(ISBN("978-4-10-101001-4")?.value == "9784101010014")
    }

    @Test func valid10ConvertsTo13() {
        // ISBN-10: 4101010013 → ISBN-13: 9784101010014
        let isbn = ISBN("4101010013")
        #expect(isbn?.value == "9784101010014")
    }

    @Test func isbn10WithXCheckDigit() {
        // ISBN-10 example: "043942089X" (Harry Potter) → 9780439420891
        let isbn = ISBN("043942089X")
        #expect(isbn?.value == "9780439420891")
    }

    @Test func rejectsInvalidChecksum13() {
        #expect(ISBN("9784101010015") == nil)
    }

    @Test func rejectsInvalidChecksum10() {
        #expect(ISBN("4101010012") == nil)
    }

    @Test func rejectsWrongLength() {
        #expect(ISBN("12345") == nil)
        #expect(ISBN("12345678901234") == nil)
    }

    @Test func rejectsNonNumeric13() {
        #expect(ISBN("978410X010014") == nil)
    }

    @Test func stripsHyphensAndSpaces() {
        #expect(ISBN("978 4 10 101001 4")?.value == "9784101010014")
    }

    @Test func lowercaseXCheckDigit() {
        // 'x' を小文字で与えても受け入れる
        #expect(ISBN("043942089x")?.value == "9780439420891")
    }

    @Test func xInWrongPositionIsRejected() {
        // ISBN-10 の X はチェックディジット位置のみ許容
        #expect(ISBN("04394X0891") == nil)
    }

    @Test func isbn13_979Prefix_accepted() {
        // 計算したチェックディジットが 9 の 979 系 ISBN
        #expect(ISBN("9791091133159")?.value == "9791091133159")
    }
}
