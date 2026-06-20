// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexPulse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexPulse", targets: ["CodexPulse"])
    ],
    targets: [
        .executableTarget(
            name: "CodexPulse",
            path: "Sources/CodexPulse"
        )
    ]
)
