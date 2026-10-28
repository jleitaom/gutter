// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Gutter",
    platforms: [.macOS(.v14)],
    targets: [
        // Window-fitting math with no AppKit state, so it can be unit tested.
        .target(name: "GutterKit", path: "Sources/GutterKit"),
        // The app is all UI and runs on the main thread, so everything in it is main-actor
        // isolated unless marked `nonisolated`.
        .executableTarget(name: "Gutter", dependencies: ["GutterKit"], path: "Sources/Gutter",
                          swiftSettings: [.defaultIsolation(MainActor.self)]),
        .testTarget(name: "GutterKitTests", dependencies: ["GutterKit"], path: "Tests/GutterKitTests"),
    ]
)
