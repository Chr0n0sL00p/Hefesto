// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hefesto",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Hefesto",
            targets: ["Hefesto"]
        ),
    ],
    targets: [
        .target(
            name: "Hefesto",
            path: ".",
            sources: ["App", "Models", "Services", "Views"]
        )
    ]
)
