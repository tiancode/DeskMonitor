// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeskMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DeskMonitor",
            path: "Sources/DeskMonitor",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
