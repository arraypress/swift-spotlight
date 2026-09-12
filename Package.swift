// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-spotlight",
    // Foundation only. The index is already on the machine and already up to date; this
    // asks it questions rather than building anything of its own. macOS only, because
    // Spotlight is.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Spotlight", targets: ["Spotlight"]),
    ],
    targets: [
        .target(name: "Spotlight"),
        .testTarget(name: "SpotlightTests", dependencies: ["Spotlight"]),
    ]
)
