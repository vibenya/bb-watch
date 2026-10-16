// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BBWatchCore",
    platforms: [
        .macOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(name: "BBWatchCore", targets: ["BBWatchCore"])
    ],
    targets: [
        .target(name: "BBWatchCore", path: "Sources/BBWatchCore"),
        .testTarget(name: "BBWatchCoreTests", dependencies: ["BBWatchCore"], path: "Tests/BBWatchCoreTests")
    ]
)
