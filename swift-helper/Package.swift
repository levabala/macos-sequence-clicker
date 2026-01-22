// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SequencerHelper",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SequencerHelper",
            path: "Sources"
        )
    ]
)
