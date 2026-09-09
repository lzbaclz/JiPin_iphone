// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JiPinCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "JiPinCore", targets: ["JiPinCore"])
    ],
    targets: [
        .target(name: "JiPinCore"),
        .testTarget(name: "JiPinCoreTests", dependencies: ["JiPinCore"])
    ]
)
