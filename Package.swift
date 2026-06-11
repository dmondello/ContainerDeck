// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ContainerDeck",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "ContainerDeck",
            path: "Sources/ContainerDeck",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
