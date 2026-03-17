// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MetalOrb",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MetalOrb", targets: ["MetalOrb"])
    ],
    targets: [
        .target(
            name: "MetalOrb",
            path: "Sources/MetalOrb",
            resources: [.process("Shaders.metal")]
        )
    ]
)
