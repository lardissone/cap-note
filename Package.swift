// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CapNote",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CapNote", targets: ["CapNote"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.1"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "CapNote",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/CapNote"
        ),
        .testTarget(
            name: "CapNoteTests",
            dependencies: ["CapNote"],
            path: "Tests/CapNoteTests"
        )
    ]
)
