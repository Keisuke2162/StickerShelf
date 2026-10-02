import Foundation
import OSLog
import Domain

private let errorLogger = Logger(subsystem: "StickerShelf", category: "GoogleBooksErrorMapper")

enum GoogleBooksErrorMapper {
    static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            if let body = String(data: data, encoding: .utf8) {
                errorLogger.error("HTTP \(http.statusCode) body: \(body, privacy: .public)")
            } else {
                errorLogger.error("HTTP \(http.statusCode) (binary body, \(data.count, privacy: .public) bytes)")
            }
            throw map(statusCode: http.statusCode, data: data)
        }
    }

    static func map(urlError: URLError) -> DomainError {
        // Notion 04「URLError（オフライン等）→ network」に従い、通信起因は原則 .network に寄せる。
        // サーバー HTTP 応答由来は URLError にならないので、ここに来る時点でクライアント／ネットワーク側事情。
        return .network
    }

    static func map(statusCode: Int, data: Data) -> DomainError {
        let decoded = try? JSONDecoder().decode(GoogleBooksErrorBodyDTO.self, from: data)
        // Google は errors[].reason / details[].reason / status / message の複数箇所に
        // 原因を散らばらせるので全部拾って lowercase で突き合わせる。
        var reasons: Set<String> = []
        for entry in decoded?.error?.errors ?? [] {
            if let reason = entry.reason { reasons.insert(reason.lowercased()) }
        }
        for detail in decoded?.error?.details ?? [] {
            if let reason = detail.reason { reasons.insert(reason.lowercased()) }
        }
        if let status = decoded?.error?.status { reasons.insert(status.lowercased()) }
        let serverMessage = decoded?.error?.message ?? ""
        let messageLower = serverMessage.lowercased()
        let looksLikeInvalidKey = messageLower.contains("api key") && (messageLower.contains("not valid") || messageLower.contains("invalid"))

        func isInvalidKeyReason() -> Bool {
            reasons.contains("keyinvalid") || reasons.contains("api_key_invalid")
                || reasons.contains("iosbundleidinvalid") || reasons.contains("ipaddressblocked")
                || looksLikeInvalidKey
        }

        switch statusCode {
        case 400:
            if isInvalidKeyReason() { return .invalidAPIKey }
            return .catalogUnavailable(reason: "HTTP 400: \(serverMessage.isEmpty ? "bad request" : serverMessage)")
        case 401:
            return .invalidAPIKey
        case 403:
            if isInvalidKeyReason() { return .invalidAPIKey }
            if reasons.contains("dailylimitexceeded") || reasons.contains("ratelimitexceeded")
                || reasons.contains("userratelimitexceeded") {
                return .catalogQuotaExceeded
            }
            // reason が無い 403 は iOS アプリ制限と匿名クォータ超過のどちらでも発生する。
            // Notion 04 の表に従い、どちらにも案内できる .catalogQuotaExceeded に倒す。
            return .catalogQuotaExceeded
        case 429:
            return .catalogQuotaExceeded
        case 500...599:
            return .catalogUnavailable(reason: "server error \(statusCode): \(serverMessage)")
        default:
            return .catalogUnavailable(reason: "HTTP \(statusCode): \(serverMessage)")
        }
    }
}
