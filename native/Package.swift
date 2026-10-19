// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "VoiceProbe", platforms: [.macOS(.v15)], products: [
    .library(name: "ProbeCore", targets: ["ProbeCore"]),
    .executable(name: "probe-checks", targets: ["ProbeChecks"])
], targets: [
    .target(name: "ProbeCore", path: "Core"),
    .executableTarget(name: "ProbeChecks", dependencies: ["ProbeCore"], path: "Checks")
])
