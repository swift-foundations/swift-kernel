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
        ),
        .library(
            name: "Kernel Test Support",
            targets: ["Kernel Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-standards/swift-standards.git", from: "0.29.0")
    ],
    targets: [
        // C shims for platform-specific functionality
        .target(
            name: "CPosixShim",
            dependencies: []
        ),
        .target(
            name: "CLinuxShim",
            dependencies: []
        ),
        .target(
            name: "CDarwinShim",
            dependencies: []
        ),
        // Cross-platform primitives (works on all platforms)
        .target(
            name: "Kernel Primitives",
            dependencies: [
                .product(name: "Binary", package: "swift-standards"),
                .target(name: "CDarwinShim", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS])),
                .target(name: "CLinuxShim", condition: .when(platforms: [.linux])),
            ]
        ),
        // POSIX-only functionality (Darwin + Linux, not Windows)
        .target(
            name: "Kernel POSIX",
            dependencies: [
                "Kernel Primitives",
                "CPosixShim",
                .target(name: "CDarwinShim", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS])),
                .target(name: "CLinuxShim", condition: .when(platforms: [.linux])),
            ]
        ),
        // Darwin-specific (kqueue, etc.)
        .target(
            name: "Kernel Darwin",
            dependencies: [
                "Kernel POSIX",
                .product(name: "Dimension", package: "swift-standards"),
            ]
        ),
        // Linux-specific (epoll, io_uring, etc.)
        .target(
            name: "Kernel Linux",
            dependencies: [
                "Kernel POSIX",
                .target(name: "CLinuxShim", condition: .when(platforms: [.linux])),
                .product(name: "Dimension", package: "swift-standards"),
            ]
        ),
        // Windows-specific (IOCP, etc.)
        .target(
            name: "Kernel Windows",
            dependencies: ["Kernel Primitives"]
        ),
        // Umbrella module
        .target(
            name: "Kernel",
            dependencies: [
                "Kernel Primitives",
                .target(name: "Kernel POSIX", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .linux])),
                .target(name: "Kernel Darwin", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS])),
                .target(name: "Kernel Linux", condition: .when(platforms: [.linux])),
                .target(name: "Kernel Windows", condition: .when(platforms: [.windows])),
                .product(name: "Dimension", package: "swift-standards"),
                .product(name: "StandardsCollections", package: "swift-standards"),
            ]
        ),
        // Test support utilities (harnesses, helpers)
        .target(
            name: "Kernel Test Support",
            dependencies: [
                "Kernel"
            ],
            path: "Tests/Support"
        ),
        // Cross-platform primitives tests
        .testTarget(
            name: "Kernel Primitives Tests",
            dependencies: [
                "Kernel Primitives",
                "Kernel Test Support",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ],
            path: "Tests/Kernel Primitives Tests"
        ),
        // POSIX-specific tests (Darwin + Linux)
        .testTarget(
            name: "Kernel POSIX Tests",
            dependencies: [
                .target(name: "Kernel POSIX", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .linux])),
                "Kernel Primitives",
                "Kernel Test Support",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ],
            path: "Tests/Kernel POSIX Tests"
        ),
        // Darwin-specific tests (macOS, iOS, tvOS, watchOS)
        .testTarget(
            name: "Kernel Darwin Tests",
            dependencies: [
                .target(name: "Kernel Darwin", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS])),
                "Kernel Primitives",
                "Kernel Test Support",
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
                "Kernel Test Support",
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
                "Kernel Test Support",
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
