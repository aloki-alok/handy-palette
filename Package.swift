// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kana",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Kana", targets: ["Kana"]),
        .executable(name: "kana-cli", targets: ["KanaCLI"]),
        .executable(name: "KanaChecks", targets: ["KanaChecks"])
    ],
    targets: [
        .target(name: "KanaCore", resources: [.copy("Resources/starter-library.json")]),
        .target(name: "KanaShared"),
        .executableTarget(name: "Kana", dependencies: ["KanaCore", "KanaShared"]),
        .executableTarget(
            name: "KanaCLI",
            dependencies: ["KanaCore", "KanaShared"]
        ),
        .executableTarget(name: "KanaChecks", dependencies: ["KanaCore", "KanaShared"])
    ]
)
