// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "SafariProfileLauncher", platforms: [.macOS(.v13)], products: [
    .executable(name: "ProfileStudio", targets: ["ProfileStudio"]),
    .executable(name: "ProfileLauncher", targets: ["ProfileLauncher"])
], targets: [
    .target(name: "LauncherCore"),
    .target(name: "MacSupport", dependencies: ["LauncherCore"]),
    .executableTarget(name: "ProfileStudio", dependencies: ["LauncherCore", "MacSupport"]),
    .executableTarget(name: "ProfileLauncher", dependencies: ["LauncherCore", "MacSupport"]),
    .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
    .testTarget(name: "MacSupportTests", dependencies: ["LauncherCore", "MacSupport"])
])
