// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HTMLStudio",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HTMLStudio", targets: ["HTMLStudio"])
    ],
    targets: [
        .target(
            name: "HTMLStudioCore",
            path: "Sources/HTMLStudioCore"
        ),
        .executableTarget(
            name: "HTMLStudio",
            dependencies: ["HTMLStudioCore"],
            path: "Sources/HTMLStudio"
        ),
        .executableTarget(
            name: "HTMLStudioSmokeTests",
            dependencies: ["HTMLStudioCore"],
            path: "Tests/HTMLStudioSmokeTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
