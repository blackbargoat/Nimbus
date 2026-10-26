// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Nimbus",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "Nimbus",
            path: "Sources/Nimbus",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
