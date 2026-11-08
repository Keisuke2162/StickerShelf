#if canImport(UIKit)
import Foundation

/// DEBUG 用の起動引数パーサ。CLAUDE.md で定義された -SeedSampleData / -StartScreen / -UseStubCatalog を扱う。
public struct StartupOptions: Sendable {
    public enum StartScreen: String, Sendable {
        case shelf, pile, calendar, detail, add, settings
    }

    public let seedSampleData: Bool
    public let startScreen: StartScreen?
    public let useStubCatalog: Bool

    public init(seedSampleData: Bool = false, startScreen: StartScreen? = nil, useStubCatalog: Bool = false) {
        self.seedSampleData = seedSampleData
        self.startScreen = startScreen
        self.useStubCatalog = useStubCatalog
    }

    public static func parse(from arguments: [String]) -> StartupOptions {
        var seed = false
        var screen: StartScreen? = nil
        var stub = false
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            let value = i + 1 < arguments.count ? arguments[i + 1] : nil
            switch arg {
            case "-SeedSampleData":
                seed = (value?.uppercased() == "YES")
                i += 2
            case "-StartScreen":
                screen = value.flatMap(StartScreen.init(rawValue:))
                i += 2
            case "-UseStubCatalog":
                stub = (value?.uppercased() == "YES")
                i += 2
            default:
                i += 1
            }
        }
        return StartupOptions(seedSampleData: seed, startScreen: screen, useStubCatalog: stub)
    }
}

#endif
