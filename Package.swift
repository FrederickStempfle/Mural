// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Mural",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Mural", targets: ["Mural"])
    ],
    dependencies: [
        .package(path: "Packages/MuralKit")
    ],
    targets: [
        .executableTarget(
            name: "Mural",
            dependencies: [
                .product(name: "MuralKit", package: "MuralKit")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MuralTests",
            dependencies: ["Mural"]
        ),
        .testTarget(
            name: "MuralKitTests",
            dependencies: [
                .product(name: "MuralKit", package: "MuralKit")
            ]
        )
    ]
)
