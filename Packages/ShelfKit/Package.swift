// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShelfKit",
    defaultLocalization: "ja",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ShelfKit", targets: ["Presentation", "Infrastructure", "Application", "Domain"]),
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Infrastructure", targets: ["Infrastructure"]),
        .library(name: "Presentation", targets: ["Presentation"]),
    ],
    targets: [
        .target(
            name: "Domain",
            path: "Sources/Domain"
        ),
        .target(
            name: "Application",
            dependencies: ["Domain"],
            path: "Sources/Application"
        ),
        .target(
            name: "Infrastructure",
            dependencies: ["Domain"],
            path: "Sources/Infrastructure"
        ),
        .target(
            name: "Presentation",
            dependencies: ["Domain", "Application"],
            path: "Sources/Presentation",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            path: "Tests/DomainTests"
        ),
        .testTarget(
            name: "ApplicationTests",
            dependencies: ["Application", "Domain"],
            path: "Tests/ApplicationTests"
        ),
        .testTarget(
            name: "InfrastructureTests",
            dependencies: ["Infrastructure", "Domain"],
            path: "Tests/InfrastructureTests",
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "PresentationTests",
            dependencies: ["Presentation", "Application", "Domain"],
            path: "Tests/PresentationTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
