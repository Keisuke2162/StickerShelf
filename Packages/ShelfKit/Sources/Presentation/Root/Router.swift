#if canImport(UIKit)
import Foundation
import Observation
import Domain

@MainActor
@Observable
public final class Router {
    public enum Tab: Hashable {
        case shelf
        case pile
        case book
        case calendar
        case settings
    }

    public var selectedTab: Tab = .shelf
    public var detailBookID: BookID?

    public init() {}
}

#endif
