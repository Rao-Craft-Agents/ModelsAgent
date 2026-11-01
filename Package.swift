// swift-tools-version:6.0
// ModelsAgent: an app's own domain types, written as Swift from compact entity lines, as a Granite agent package.
// An app that links it finds the `models` agent through Granite's roster, with nothing listed by hand.

import PackageDescription

let package = Package(
    name: "ModelsAgent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ModelsAgent", targets: ["ModelsAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "ModelsAgent",
            dependencies: [.product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "ModelsAgentTests",
            dependencies: ["ModelsAgent", .product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
