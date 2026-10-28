// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SnappyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SnappyCore", targets: ["SnappyCore"]),
    ],
    targets: [
        .target(name: "SnappyCore"),
        .testTarget(name: "SnappyCoreTests", dependencies: ["SnappyCore"]),
    ]
)
