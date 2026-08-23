// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Handy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Handy", targets: ["Handy"]),
        .executable(name: "HandyCLI", targets: ["HandyCLI"]),
        .executable(name: "HandyChecks", targets: ["HandyChecks"])
    ],
    targets: [
        .target(name: "HandyCore", resources: [.copy("Resources/starter-library.json")]),
        .target(name: "HandyShared"),
        .executableTarget(name: "Handy", dependencies: ["HandyCore", "HandyShared"]),
        .executableTarget(
            name: "HandyCLI",
            dependencies: ["HandyCore", "HandyShared"]
        ),
        .executableTarget(name: "HandyChecks", dependencies: ["HandyCore"])
    ]
)
