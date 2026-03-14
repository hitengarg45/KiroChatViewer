// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KiroChatViewer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),
        .package(url: "https://github.com/JohnSundell/Splash.git", from: "0.16.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "KiroChatViewer",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Splash", package: "Splash"),
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "KiroChatViewerTests",
            dependencies: [
                "KiroChatViewer",
                .product(name: "Testing", package: "swift-testing")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
