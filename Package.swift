// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ContainerDeck",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        // Unica dipendenza esterna: parser YAML per la feature Stacks.
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .executableTarget(
            name: "ContainerDeck",
            dependencies: ["Yams"],
            path: "Sources/ContainerDeck",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
