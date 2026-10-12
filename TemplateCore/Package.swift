// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TemplateCore",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "TemplateCore", targets: ["TemplateCore"])
    ],
    targets: [
        .target(
            name: "TemplateCore",
            swiftSettings: [
                // Services default to the main actor (docs/adr/0001-templatecore-package-with-mainactor-default-isolation.md);
                // domain value types are explicitly nonisolated so background work can read them.
                .defaultIsolation(MainActor.self)
            ]
        )
    ]
)
