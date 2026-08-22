// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Handy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Handy", targets: ["Handy"]),
        .executable(name: "HandyChecks", targets: ["HandyChecks"])
    ],
    targets: [
        .target(name: "HandyCore", resources: [.copy("Resources/starter-library.json")]),
        .executableTarget(name: "Handy", dependencies: ["HandyCore"]),
        .executableTarget(name: "HandyChecks", dependencies: ["HandyCore"])
    ]
)
