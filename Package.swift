// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "clockifish",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Swift Argument Parser for CLI command structure
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "clockifish",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/clockifish",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
    ]
)
