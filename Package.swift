// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArchiveKit",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ArchiveKit",
            targets: ["ArchiveKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/okferret/libarchive.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ArchiveKit",
            dependencies: [
                .product(name: "libarchive", package: "libarchive"),
            ]
        ),
        .testTarget(
            name: "ArchiveKitTests",
            dependencies: ["ArchiveKit"]
        ),
    ]
)
