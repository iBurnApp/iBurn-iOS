// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlayaAPI",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PlayaAPI",
            targets: ["PlayaAPI"]
        ),
        .library(
            name: "PlayaAPITestHelpers",
            targets: ["PlayaAPITestHelpers"]
        ),
    ],
    dependencies: [
        .package(path: "../../Submodules/iBurn-Data")
    ],
    targets: [
        .target(
            name: "PlayaAPI",
            dependencies: []
        ),
        .target(
            name: "PlayaAPITestHelpers",
            dependencies: ["PlayaAPI"]
        ),
        .testTarget(
            name: "PlayaAPITests",
            dependencies: [
                "PlayaAPI", 
                "PlayaAPITestHelpers",
                .product(name: "iBurn2025APIData", package: "iBurn-Data")
            ]
        ),
    ]
)