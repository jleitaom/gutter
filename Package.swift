// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Gutter",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Update checks. Pinned, so a new Sparkle release never changes a build on its own.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        // Window-fitting math with no AppKit state, so it can be unit tested.
        .target(name: "GutterKit", path: "Sources/GutterKit"),
        // The app is all UI and runs on the main thread, so everything in it is main-actor
        // isolated unless marked `nonisolated`.
        .executableTarget(
            name: "Gutter",
            dependencies: ["GutterKit", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Gutter",
            swiftSettings: [.defaultIsolation(MainActor.self)],
            // build.sh puts Sparkle.framework in Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "GutterKitTests", dependencies: ["GutterKit"], path: "Tests/GutterKitTests"),
    ]
)
