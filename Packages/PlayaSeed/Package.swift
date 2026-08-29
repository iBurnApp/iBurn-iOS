// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlayaSeed",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "playa-seed",
            targets: ["playa-seed"]
        ),
    ],
    dependencies: [
        .package(path: "../PlayaDB"),
        .package(path: "../PlayaColors"),
    ],
    targets: [
        .executableTarget(
            name: "playa-seed",
            dependencies: [
                .product(name: "PlayaDB", package: "PlayaDB"),
                .product(name: "PlayaColors", package: "PlayaColors"),
            ]
        ),
        .testTarget(
            name: "PlayaSeedTests",
            dependencies: ["playa-seed"]
        ),
    ]
)
