// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuotaForCodex",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "QuotaCore", targets: ["QuotaCore"]),
        .executable(name: "QuotaProbe", targets: ["QuotaProbe"]),
        .executable(name: "QuotaSmoke", targets: ["QuotaSmoke"])
    ],
    targets: [
        .target(
            name: "QuotaCore",
            path: "Sources/QuotaCore"
        ),
        .executableTarget(
            name: "QuotaProbe",
            dependencies: ["QuotaCore"],
            path: "Sources/QuotaProbe"
        ),
        .executableTarget(
            name: "QuotaSmoke",
            dependencies: ["QuotaCore"],
            path: "Sources/QuotaSmoke"
        ),
        .testTarget(
            name: "QuotaCoreTests",
            dependencies: ["QuotaCore"],
            path: "Tests/QuotaCoreTests"
        )
    ]
)
