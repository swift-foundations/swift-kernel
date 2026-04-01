// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "swift-kernel",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Kernel",
            targets: ["Kernel"]
        ),
        .library(
            name: "Kernel Test Support",
            targets: ["Kernel Test Support"]
        )
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-kernel-primitives"),
        .package(path: "../../swift-primitives/swift-system-primitives"),
        .package(path: "../../swift-primitives/swift-binary-primitives"),
        .package(path: "../../swift-primitives/swift-dimension-primitives"),
        .package(path: "../../swift-primitives/swift-queue-primitives"),
        .package(path: "../../swift-primitives/swift-reference-primitives"),
        .package(path: "../../swift-primitives/swift-ownership-primitives"),
        .package(path: "../swift-posix"),
        .package(path: "../swift-darwin"),
        .package(path: "../swift-linux"),
        .package(path: "../swift-windows"),
        .package(path: "../swift-strings")
    ],
    targets: [
        // MARK: - Core
        .target(
            name: "Kernel Core",
            dependencies: [
                .product(name: "Kernel Primitives", package: "swift-kernel-primitives"),
                .product(name: "System Primitives", package: "swift-system-primitives"),
                .product(name: "Reference Primitives", package: "swift-reference-primitives"),
                .product(name: "Ownership Primitives", package: "swift-ownership-primitives"),
                .product(name: "Dimension Primitives", package: "swift-dimension-primitives"),
                .product(name: "Queue Primitives", package: "swift-queue-primitives"),
                .product(name: "POSIX Kernel", package: "swift-posix", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
                .product(name: "Darwin Kernel", package: "swift-darwin", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])),
                .product(name: "Darwin System", package: "swift-darwin", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])),
                .product(name: "Linux Kernel", package: "swift-linux", condition: .when(platforms: [.linux])),
                .product(name: "Linux System", package: "swift-linux", condition: .when(platforms: [.linux])),
                .product(name: "Windows Kernel", package: "swift-windows", condition: .when(platforms: [.windows])),
            ]
        ),

        // MARK: - System
        .target(
            name: "Kernel System",
            dependencies: ["Kernel Core"]
        ),

        // MARK: - Thread
        .target(
            name: "Kernel Thread",
            dependencies: ["Kernel Core", "Kernel System"]
        ),

        // MARK: - File
        .target(
            name: "Kernel File",
            dependencies: [
                "Kernel Core",
                .product(name: "Kernel String Primitives", package: "swift-kernel-primitives"),
            ]
        ),

        // MARK: - Continuation
        .target(
            name: "Kernel Continuation",
            dependencies: ["Kernel Core"]
        ),

        // MARK: - Umbrella
        .target(
            name: "Kernel",
            dependencies: [
                "Kernel Core",
                "Kernel System",
                "Kernel Thread",
                "Kernel File",
                "Kernel Continuation",
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Kernel Test Support",
            dependencies: [
                "Kernel",
                .product(name: "Kernel Primitives Test Support", package: "swift-kernel-primitives"),
                .product(name: "Strings", package: "swift-strings")
            ],
            path: "Tests/Support",
            exclude: ["_Lock Test Process"]
        ),
        // Helper executable for multi-process lock contention tests
        .executableTarget(
            name: "_Lock Test Process",
            dependencies: [
                "Kernel",
                .product(name: "Kernel Primitives", package: "swift-kernel-primitives"),
                .product(name: "Binary Primitives", package: "swift-binary-primitives")
            ],
            path: "Tests/Support/_Lock Test Process"
        ),
        .testTarget(
            name: "Kernel Tests",
            dependencies: [
                "Kernel",
                "Kernel Core",
                "Kernel Thread",
                "Kernel File",
                "Kernel Test Support",
            ],
            path: "Tests/Kernel Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
