// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScreenShotManagerCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ScreenShotManagerCore",
            targets: ["ScreenShotManagerCore"]
        ),
    ],
    targets: [
        .target(
            name: "ScreenShotManagerCore",
            resources: [
                .process("CoreData/ScreenShotManager.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "ScreenShotManagerCoreTests",
            dependencies: ["ScreenShotManagerCore"]
        ),
    ]
)
