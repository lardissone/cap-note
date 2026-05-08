// swift-tools-version: 5.9
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
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.2.1")
    ],
    targets: [
        .executableTarget(
            name: "CapNote",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
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
