// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-kernel",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "Kernel",
            targets: ["Kernel"]
        ),
        .library(
            name: "Kernel Test Support",
            targets: ["Kernel Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-kernel-primitives.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-primitives/swift-system-primitives.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-primitives/swift-binary-primitives.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-primitives/swift-dimension-primitives.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-primitives/swift-container-primitives.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-primitives/swift-test-primitives.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-foundations/swift-posix.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-foundations/swift-darwin.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-foundations/swift-linux.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-foundations/swift-windows.git", from: "0.0.1"),
    ],
    targets: [
        // Umbrella/policy module
        .target(
            name: "Kernel",
            dependencies: [
                .product(name: "Kernel Primitives", package: "swift-kernel-primitives"),
                .product(name: "System Primitives", package: "swift-system-primitives"),
                .product(name: "POSIX Kernel", package: "swift-posix", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
                .product(name: "Darwin Kernel", package: "swift-darwin", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])),
                .product(name: "Linux Kernel", package: "swift-linux", condition: .when(platforms: [.linux])),
                .product(name: "Windows Kernel", package: "swift-windows", condition: .when(platforms: [.windows])),
                .product(name: "Dimension Primitives", package: "swift-dimension-primitives"),
                .product(name: "Container Primitives", package: "swift-container-primitives"),
            ]
        ),
        // Test support utilities (harnesses, helpers)
        .target(
            name: "Kernel Test Support",
            dependencies: [
                "Kernel",
                .product(name: "Kernel Primitives Test Support", package: "swift-kernel-primitives"),
            ],
            path: "Tests/Support"
        ),
        // Integration tests (uses full Kernel module)
        .testTarget(
            name: "Kernel Tests",
            dependencies: [
                "Kernel",
                "Kernel Test Support",
                .product(name: "Test Primitives", package: "swift-test-primitives"),
            ],
            path: "Tests/Kernel Tests"
        ),
        .executableTarget(
            name: "_Lock Test Process",
            dependencies: [
                "Kernel",
                .product(name: "Kernel Primitives", package: "swift-kernel-primitives"),
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
