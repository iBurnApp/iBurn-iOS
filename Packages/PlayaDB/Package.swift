// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlayaDB",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PlayaDB",
            targets: ["PlayaDB"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "7.6.1")),
        .package(path: "../PlayaAPI"),
    ],
    targets: [
        .target(
            name: "PlayaDB",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                "PlayaAPI"
            ]
        ),
        .testTarget(
            name: "PlayaDBTests",
            dependencies: [
                "PlayaDB",
                "PlayaAPI"
            ]
        ),
    ]
)
