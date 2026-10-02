import Foundation
import Domain

enum GoogleBooksErrorMapper {
    static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw map(statusCode: http.statusCode, data: data)
        }
    }

    static func map(urlError: URLError) -> DomainError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut:
            return .network
        default:
            return .catalogUnavailable(reason: urlError.localizedDescription)
        }
    }

    static func map(statusCode: Int, data: Data) -> DomainError {
        let decoded = try? JSONDecoder().decode(GoogleBooksErrorBodyDTO.self, from: data)
        let reasons = Set((decoded?.error?.errors ?? []).compactMap { $0.reason?.lowercased() })

        switch statusCode {
        case 400:
            if reasons.contains("keyinvalid") || reasons.contains("api_key_invalid") {
                return .invalidAPIKey
            }
            return .catalogUnavailable(reason: decoded?.error?.message ?? "bad request")
        case 401:
            return .invalidAPIKey
        case 403:
            if reasons.contains("ipaddressblocked") || reasons.contains("iosbundleidinvalid")
                || reasons.contains("keyinvalid") || reasons.contains("api_key_invalid") {
                return .invalidAPIKey
            }
            if reasons.contains("dailylimitexceeded") || reasons.contains("ratelimitexceeded")
                || reasons.contains("userratelimitexceeded") {
                return .catalogQuotaExceeded
            }
            return .catalogQuotaExceeded
        case 429:
            return .catalogQuotaExceeded
        case 500...599:
            return .catalogUnavailable(reason: "server error \(statusCode)")
        default:
            return .catalogUnavailable(reason: "http \(statusCode)")
        }
    }
}
