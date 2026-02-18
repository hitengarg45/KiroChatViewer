// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KiroChatViewer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "KiroChatViewer",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ]
        )
    ]
)
