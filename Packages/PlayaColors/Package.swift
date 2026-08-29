// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlayaColors",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "PlayaColors",
            targets: ["PlayaColors"]
        ),
    ],
    targets: [
        .target(
            name: "PlayaColors"
        ),
        .testTarget(
            name: "PlayaColorsTests",
            dependencies: ["PlayaColors"]
        ),
    ]
)
