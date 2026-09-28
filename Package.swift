// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "桌伴",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Launch", targets: ["Launch"])
    ],
    targets: [
        .target(
            name: "ScreenEdgeBridge",
            path: "Sources/ScreenEdgeBridge",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .executableTarget(
            name: "Launch",
            dependencies: ["ScreenEdgeBridge"],
            path: "Sources/Launch"
        )
    ],
    swiftLanguageVersions: [.v5]
)
