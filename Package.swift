// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FlagKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "FlagKit",
            targets: ["FlagKit"]
        )
    ],
    targets: [
        .target(
            name: "FlagKit",
            path: "Sources/FlagKit"
        ),
        .testTarget(
            name: "FlagKitTests",
            dependencies: ["FlagKit"],
            path: "Tests/FlagKitTests"
        ),
        .executableTarget(
            name: "sdk-lab",
            dependencies: ["FlagKit"],
            path: "Sources/SdkLab"
        )
    ]
)
