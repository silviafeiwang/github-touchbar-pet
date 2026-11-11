// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CommitPetTouchBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CommitPetTouchBar", targets: ["CommitPetTouchBar"])
    ],
    targets: [
        .target(
            name: "TouchBarPrivate",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "CommitPetTouchBar",
            dependencies: ["TouchBarPrivate"]
        )
    ]
)
