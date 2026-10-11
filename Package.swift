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

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
