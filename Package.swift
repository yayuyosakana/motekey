// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MoteKeyBootstrap",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "MoteKeyConfig", targets: ["MoteKeyConfig"]),
        .library(name: "MoteKeyShared", targets: ["MoteKeyShared"]),
        .library(name: "MoteKeyHostAppCore", targets: ["MoteKeyHostAppCore"]),
        .library(name: "MoteKeyKeyboardRuntimeCore", targets: ["MoteKeyKeyboardRuntimeCore"])
    ],
    targets: [
        .target(
            name: "MoteKeyConfig",
            path: "Config",
            exclude: ["Secrets.xcconfig.template"],
            sources: ["APIConfig.swift"]
        ),
        .target(
            name: "MoteKeyShared",
            path: "Shared"
        ),
        .target(
            name: "MoteKeyHostAppCore",
            dependencies: ["MoteKeyConfig"],
            path: "HostApp",
            exclude: [
                "HostRootView.swift",
                "Views"
            ],
            sources: [
                "AppGroupStore.swift",
                "GeminiTextHabitAnalyzer.swift",
                "HostAppState.swift",
                "HostCopy.swift",
                "HostRoute.swift"
            ]
        ),
        .target(
            name: "MoteKeyKeyboardRuntimeCore",
            dependencies: ["MoteKeyConfig"],
            path: "KeyboardExtension",
            exclude: [
                "UI",
                "Services/README.md",
                "State/README.md"
            ],
            sources: [
                "Services",
                "State"
            ]
        ),
        .testTarget(
            name: "MoteKeyConfigTests",
            dependencies: ["MoteKeyConfig"],
            path: "Tests/MoteKeyConfigTests"
        ),
        .testTarget(
            name: "MoteKeySharedTests",
            dependencies: ["MoteKeyShared"],
            path: "Tests/MoteKeySharedTests"
        )
    ]
)
