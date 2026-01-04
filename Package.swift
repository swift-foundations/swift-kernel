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
            dependencies: []
        ),
        .target(
            name: "Kernel Primitives",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "Binary", package: "swift-standards"),
            ]
        ),
        .target(
            name: "Kernel Darwin",
            dependencies: [
                "Kernel Primitives",
                .product(name: "Dimension", package: "swift-standards"),
            ]
        ),
        .target(
            name: "Kernel Linux",
            dependencies: [
                "Kernel Primitives",
                .target(name: "CLinuxShim", condition: .when(platforms: [.linux])),
                .product(name: "Dimension", package: "swift-standards"),
            ]
        ),
        .target(
            name: "Kernel Windows",
            dependencies: ["Kernel Primitives"]
        ),
        .target(
            name: "Kernel",
            dependencies: [
                "Kernel Primitives",
                .target(name: "Kernel Darwin", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS])),
                .target(name: "Kernel Linux", condition: .when(platforms: [.linux])),
                .target(name: "Kernel Windows", condition: .when(platforms: [.windows]))
            ]
        ),
        // Cross-platform primitives tests
        .testTarget(
            name: "Kernel Primitives Tests",
            dependencies: [
                "Kernel Primitives",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ],
            path: "Tests/Kernel Primitives Tests"
        ),
        // Darwin-specific tests (macOS, iOS, tvOS, watchOS)
        .testTarget(
            name: "Kernel Darwin Tests",
            dependencies: [
                .target(name: "Kernel Darwin", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS])),
                "Kernel Primitives",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ],
            path: "Tests/Kernel Darwin Tests"
        ),
        // Linux-specific tests
        .testTarget(
            name: "Kernel Linux Tests",
            dependencies: [
                .target(name: "Kernel Linux", condition: .when(platforms: [.linux])),
                "Kernel Primitives",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ],
            path: "Tests/Kernel Linux Tests"
        ),
        // Windows-specific tests
        .testTarget(
            name: "Kernel Windows Tests",
            dependencies: [
                .target(name: "Kernel Windows", condition: .when(platforms: [.windows])),
                "Kernel Primitives",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ],
            path: "Tests/Kernel Windows Tests"
        ),
        // Integration tests (uses full Kernel module)
        .testTarget(
            name: "Kernel Tests",
            dependencies: [
                "Kernel",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ],
            path: "Tests/Kernel Tests"
        ),
        .executableTarget(
            name: "_Lock Test Process",
            dependencies: ["Kernel"]
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
