// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "hkd",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "hkd",
            path: "Sources/hkd",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Cocoa"),
                // Embed Info.plist so macOS can attribute TCC permissions
                // to a stable bundle identifier.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist",
                ])
            ]
        ),
        .testTarget(
            name: "hkdTests",
            dependencies: ["hkd"],
            path: "Tests/hkdTests"
        )
    ]
)
