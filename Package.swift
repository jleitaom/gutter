// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Gutter",
    platforms: [.macOS(.v14)],
    targets: [
        // Window-fitting math with no AppKit state, so it can be unit tested.
        .target(name: "GutterKit", path: "Sources/GutterKit"),
        .executableTarget(name: "Gutter", dependencies: ["GutterKit"], path: "Sources/Gutter"),
        .testTarget(name: "GutterKitTests", dependencies: ["GutterKit"], path: "Tests/GutterKitTests"),
    ]
)
