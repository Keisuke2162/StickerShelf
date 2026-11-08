import Foundation

enum FixtureLoader {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
                ?? Bundle.module.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "FixtureLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fixture '\(name).json' not found"])
        }
        return try Data(contentsOf: url)
    }
}
