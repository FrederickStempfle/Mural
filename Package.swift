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
    targets: [
        .executableTarget(
            name: "Mural",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MuralTests",
            dependencies: ["Mural"]
        )
    ]
)
