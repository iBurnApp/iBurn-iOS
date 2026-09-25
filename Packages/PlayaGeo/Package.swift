// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlayaGeo",
    platforms: [
        .iOS("18.0"),
        .macOS(.v13),
        .watchOS("11.0")
    ],
    products: [
        .library(
            name: "PlayaGeo",
            targets: ["PlayaGeo"]
        ),
    ],
    targets: [
        .target(
            name: "PlayaGeo"
        ),
        .testTarget(
            name: "PlayaGeoTests",
            dependencies: ["PlayaGeo"],
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
