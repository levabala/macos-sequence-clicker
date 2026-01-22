// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "E2ETester",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.5.0"))
    ],
    targets: [
        .executableTarget(
            name: "E2ETester",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources"
        )
    ]
)
