import Foundation

public struct PurchaseInfo: Hashable, Sendable, Codable {
    public var purchasedAt: Date?
    public var place: String

    public init(purchasedAt: Date? = nil, place: String = "") {
        self.purchasedAt = purchasedAt
        self.place = place
    }
}
