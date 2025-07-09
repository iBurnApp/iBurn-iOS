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
        .package(url: "https://github.com/pointfreeco/sharing-grdb", from: "0.1.0"),
        .package(path: "../PlayaAPI"),
    ],
    targets: [
        .target(
            name: "PlayaDB",
            dependencies: [
                .product(name: "SharingGRDB", package: "sharing-grdb"),
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