// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ContainerDeck",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        // Parser YAML per la feature Stacks.
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
        // Emulatore terminale per la shell integrata nei container.
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "ContainerDeck",
            dependencies: ["Yams", "SwiftTerm"],
            path: "Sources/ContainerDeck",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
