// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AlarmAppCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "AlarmAppCore", targets: ["AlarmAppCore"])
    ],
    targets: [
        .target(
            name: "AlarmAppCore",
            path: "Sources/AlarmAppCore"
        ),
        .testTarget(
            name: "AlarmAppCoreTests",
            dependencies: ["AlarmAppCore"],
            path: "Tests/AlarmAppCoreTests"
        )
    ]
)
