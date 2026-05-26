// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Switchboard",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Switchboard",
            path: "Sources/Switchboard",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SwitchboardTests",
            dependencies: ["Switchboard"],
            path: "Tests/SwitchboardTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
