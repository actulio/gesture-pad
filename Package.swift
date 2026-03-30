// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GesturePad",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "GesturePad",
            path: "Sources/GesturePad",
            linkerSettings: [
                .unsafeFlags(["-framework", "ApplicationServices"]),
            ]
        ),
        .testTarget(
            name: "GesturePadTests",
            dependencies: ["GesturePad"],
            path: "Tests/GesturePadTests"
        ),
    ]
)
