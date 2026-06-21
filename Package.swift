// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "hkd",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "hkd",
            path: "Sources/hkd",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-link-objc-runtime"])
            ],
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Cocoa"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        )
    ]
)
