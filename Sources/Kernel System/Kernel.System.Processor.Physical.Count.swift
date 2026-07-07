//
//  System.Processor.Physical.Count.swift
//  swift-kernel
//
//  Physical processor count — Linux/Windows fallback only.
//
//  On Apple platforms, `swift-darwin`'s `Darwin System` target owns
//  `System.Processor.Physical.count` (sysctl "hw.physicalcpu") directly per
//  [PLAT-ARCH-026] / [PLAT-ARCH-028]. swift-kernel MUST NOT also define it there:
//  a swift-kernel definition at the same `System.Processor.Physical.count` name
//  collides with the platform package's definition (re-exported via Kernel),
//  producing an "ambiguous use of 'count'" error for any consumer that reads
//  `System.Processor.Physical.count` through `import Kernel`. The platform package
//  is the canonical owner; the cross-platform name resolves per-platform through
//  the re-export.
//

#if os(Linux) || os(Android) || os(OpenBSD) || os(Windows)
    extension System.Processor.Physical {
        /// Number of physical processors.
        ///
        /// Linux/Windows fallback: returns the online processor count. Linux does not
        /// distinguish physical from logical without parsing `/proc/cpuinfo`; a precise
        /// per-platform physical count belongs in `swift-linux` / `swift-windows`'s own
        /// `System` target (parallel to `swift-darwin`'s) per [PLAT-ARCH-026].
        @inlinable
        public static var count: System.Processor.Count {
            System.processorCount
        }
    }
#endif
