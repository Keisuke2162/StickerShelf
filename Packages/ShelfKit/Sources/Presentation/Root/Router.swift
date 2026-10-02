#if canImport(UIKit)
import Foundation
import Observation
import Domain

@MainActor
@Observable
public final class Router {
    public enum Tab: Hashable {
        case board
        case calendar
        case settings
    }

    public enum BoardMode: Hashable {
        case shelf
        case pile
    }

    public var selectedTab: Tab = .board
    public var boardMode: BoardMode = .shelf
    public var detailBookID: BookID?
    public var isAddingBook: Bool = false

    public init() {}
}

#endif
