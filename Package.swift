// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "OpenRec",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenRecCore",
            targets: ["OpenRecCore"]
        ),
        .executable(
            name: "OpenRecApp",
            targets: ["OpenRecApp"]
        )
    ],
    targets: [
        .target(
            name: "OpenRecCore"
        ),
        .executableTarget(
            name: "OpenRecApp",
            dependencies: ["OpenRecCore"]
        ),
        .testTarget(
            name: "OpenRecCoreTests",
            dependencies: ["OpenRecCore"]
        ),
        .testTarget(
            name: "OpenRecAppTests",
            dependencies: ["OpenRecApp"]
        )
    ]
)
