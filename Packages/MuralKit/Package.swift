// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MuralKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MuralKit", targets: ["MuralKit"])
    ],
    targets: [
        .target(name: "MuralKit")
    ]
)
