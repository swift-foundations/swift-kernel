// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-kernel",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(
            name: "Kernel",
            targets: ["Kernel"]
        )
    ],
    dependencies: [
        // swift-system for internal use only (Errno, FilePath bridging)
        // NOT re-exported from Kernel's public API
        .package(url: "https://github.com/apple/swift-system", from: "1.4.0"),
        .package(url: "https://github.com/swift-standards/swift-standards", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "CLinuxShim",
            dependencies: [],
            path: "Sources/CLinuxShim"
        ),
        .target(
            name: "Kernel",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
                .target(name: "CLinuxShim", condition: .when(platforms: [.linux]))
            ]
        ),
        .testTarget(
            name: "Kernel Tests",
            dependencies: [
                "Kernel",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ]
        )
    ]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility")
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
