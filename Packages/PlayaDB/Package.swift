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
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.24.0"),
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