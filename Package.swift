// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArchiveKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ArchiveKit",
            targets: ["ArchiveKit"]),
    ],
    dependencies: [
        // 注意：当前使用 branch: "main" 跟踪最新提交，构建结果不可重现。
        // 建议在生产环境中改为固定版本，例如：
        //   .package(url: "https://github.com/okferret/libarchive.git", from: "x.y.z")
        // 或：
        //   .package(url: "https://github.com/okferret/libarchive.git", exact: "x.y.z")
        .package(url: "https://github.com/okferret/libarchive.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ArchiveKit",
            dependencies: [
                .product(name: "libarchive", package: "libarchive"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("bz2"),
                .linkedLibrary("xml2"),
                .linkedLibrary("iconv"),
            ]
        ),
        .testTarget(
            name: "ArchiveKitTests",
            dependencies: ["ArchiveKit"]
        ),
    ]
)
