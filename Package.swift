// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StarkHUD",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "StarkHUD",
            targets: ["StarkHUD"]
        ),
    ],
    targets: [
        .target(
            name: "StarkHUD",
            path: ".",
            sources: ["App", "Models", "Services", "Views"]
        )
    ]
)
