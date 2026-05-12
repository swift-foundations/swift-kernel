// swift-tools-version: 6.3.1

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
        // MARK: - Core
        .library(
            name: "Kernel Core",
            targets: ["Kernel Core"]
        ),
        // MARK: - Domains
        .library(
            name: "Kernel System",
            targets: ["Kernel System"]
        ),
        .library(
            name: "Kernel Thread",
            targets: ["Kernel Thread"]
        ),
        .library(
            name: "Kernel File",
            targets: ["Kernel File"]
        ),
        .library(
            name: "Kernel Event",
            targets: ["Kernel Event"]
        ),
        .library(
            name: "Kernel Completion",
            targets: ["Kernel Completion"]
        ),
        .library(
            name: "Kernel Clock",
            targets: ["Kernel Clock"]
        ),
        .library(
            name: "Kernel Terminal",
            targets: ["Kernel Terminal"]
        ),
        // MARK: - Umbrella
        .library(
            name: "Kernel",
            targets: ["Kernel"]
        ),
        // MARK: - Test Support
        .library(
            name: "Kernel Test Support",
            targets: ["Kernel Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-clock-primitives"),
        .package(path: "../../swift-primitives/swift-system-primitives"),
        .package(path: "../../swift-primitives/swift-binary-primitives"),
        .package(path: "../../swift-primitives/swift-cardinal-primitives"),
        .package(path: "../../swift-primitives/swift-tagged-primitives"),
        .package(path: "../../swift-primitives/swift-time-primitives"),
        .package(path: "../../swift-primitives/swift-ascii-primitives"),
        .package(path: "../../swift-primitives/swift-dimension-primitives"),
        .package(path: "../../swift-primitives/swift-queue-primitives"),
        .package(path: "../../swift-primitives/swift-reference-primitives"),
        .package(path: "../../swift-primitives/swift-ownership-primitives"),
        .package(path: "../../swift-primitives/swift-error-primitives"),
        .package(path: "../../swift-primitives/swift-random-primitives"),
        .package(path: "../../swift-primitives/swift-path-primitives"),
        .package(path: "../../swift-primitives/swift-string-primitives"),
        .package(path: "../../swift-primitives/swift-memory-primitives"),
        .package(path: "../../swift-primitives/swift-dictionary-primitives"),
        .package(path: "../../swift-primitives/swift-terminal-primitives"),
        .package(path: "../swift-cpu"),
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
                .product(name: "Binary Primitives Core", package: "swift-binary-primitives"),
                .product(name: "CPU", package: "swift-cpu"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                .product(name: "Time Primitives Core", package: "swift-time-primitives"),
                .product(name: "ASCII Primitives", package: "swift-ascii-primitives"),
                .product(name: "Clock Primitives", package: "swift-clock-primitives"),
                .product(name: "Error Primitives", package: "swift-error-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Random Primitives", package: "swift-random-primitives"),
                .product(name: "System Primitives", package: "swift-system-primitives"),
                .product(name: "Path Primitives", package: "swift-path-primitives"),
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
            dependencies: [
                "Kernel Core",
                "Kernel System",
                .product(name: "Windows Kernel Thread", package: "swift-windows",
                         condition: .when(platforms: [.windows])),
            ]
        ),

        // MARK: - File
        .target(
            name: "Kernel File",
            dependencies: [
                "Kernel Core",
                .product(name: "String Primitives", package: "swift-string-primitives"),
                .product(name: "Windows Kernel File", package: "swift-windows",
                         condition: .when(platforms: [.windows])),
            ]
        ),

        // MARK: - Event
        .target(
            name: "Kernel Event",
            dependencies: [
                "Kernel Core",
                .product(name: "Dictionary Primitives", package: "swift-dictionary-primitives"),
                .product(name: "POSIX Kernel Descriptor", package: "swift-posix",
                         condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
                .product(name: "Linux Kernel Event", package: "swift-linux",
                         condition: .when(platforms: [.linux])),
            ]
        ),

        // MARK: - Completion
        .target(
            name: "Kernel Completion",
            dependencies: [
                "Kernel Core",
                .product(name: "Linux Kernel IO Uring", package: "swift-linux",
                         condition: .when(platforms: [.linux])),
            ]
        ),

        // MARK: - Clock
        // Narrow cross-platform Clock surface — does NOT go through Kernel Core,
        // to avoid the POSIX Kernel umbrella's String_Primitives re-export.
        .target(
            name: "Kernel Clock",
            dependencies: [
                .product(name: "Clock Primitives", package: "swift-clock-primitives"),
                .product(name: "POSIX Kernel Clock", package: "swift-posix",
                         condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
                .product(name: "Windows Kernel Clock", package: "swift-windows",
                         condition: .when(platforms: [.windows])),
            ]
        ),

        // MARK: - Terminal
        // Cross-platform Terminal.Mode.Raw.Token (relocated from L1
        // swift-terminal-primitives in Cycle 22 because Token.Previous's
        // .posix case carries Kernel.Termios.Attributes — an L2 type post-
        // Cycle 22 — so Token must be at L3 to compose L1 namespace + L2 type).
        .target(
            name: "Kernel Terminal",
            dependencies: [
                "Kernel Core",
                .product(name: "Terminal Primitives Core", package: "swift-terminal-primitives"),
                .product(name: "POSIX Kernel Terminal", package: "swift-posix",
                         condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Kernel",
            dependencies: [
                "Kernel Core",
                "Kernel System",
                "Kernel Thread",
                "Kernel File",
                "Kernel Event",
                "Kernel Completion",
                "Kernel Clock",
                .product(name: "POSIX Kernel Descriptor", package: "swift-posix",
                         condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
                .product(name: "POSIX Kernel Directory", package: "swift-posix",
                         condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
                .product(name: "POSIX Kernel Socket", package: "swift-posix",
                         condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
                .product(name: "Windows Kernel Descriptor", package: "swift-windows",
                         condition: .when(platforms: [.windows])),
                .product(name: "Windows Kernel Socket", package: "swift-windows",
                         condition: .when(platforms: [.windows])),
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Kernel Test Support",
            dependencies: [
                "Kernel",
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
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
                .product(name: "POSIX Kernel Descriptor", package: "swift-posix",
                         condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .linux])),
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
                "Kernel Event",
                "Kernel Completion",
                "Kernel Test Support",
                .product(name: "Tagged Primitives Standard Library Integration", package: "swift-tagged-primitives"),
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
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
