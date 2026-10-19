// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "VoiceProbe", platforms: [.macOS(.v15)], products: [
    .library(name: "ProbeCore", targets: ["ProbeCore"]),
    .executable(name: "probe-checks", targets: ["ProbeChecks"]),
    .executable(name: "codec-checks", targets: ["CodecChecks"])
], targets: [
    .target(name: "ProbeCore", path: "Core"),
    .target(name: "ProbeCodec", dependencies: ["ProbeCore"], path: "Codec"),
    .executableTarget(name: "CodecChecks", dependencies: ["ProbeCodec", "ProbeCore"], path: "CodecChecks"),
    .executableTarget(name: "ProbeChecks", dependencies: ["ProbeCore"], path: "Checks")
])
