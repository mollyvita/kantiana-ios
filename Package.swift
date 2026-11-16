// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KantianaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KantianaKit", targets: ["KantianaKit"]),
    ],
    targets: [
        .target(name: "KantianaKit"),
        .executableTarget(name: "kantiana-smoke", dependencies: ["KantianaKit"]),
        .testTarget(name: "KantianaKitTests", dependencies: ["KantianaKit"]),
    ]
)
