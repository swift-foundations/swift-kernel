//
//  System.Processor.Physical.Count.swift
//  swift-kernel
//
//  Cross-platform typed physical processor count accessor.
//

extension System.Processor.Physical {
    /// Number of physical processors.
    ///
    /// Returns the physical core count, excluding hyperthreading.
    ///
    /// ## Platform Behavior
    ///
    /// - **Darwin**: Uses `sysctl("hw.physicalcpu")` for true physical count.
    /// - **Linux**: Falls back to online processor count (`sysconf`). Linux does not
    ///   easily distinguish physical from logical without parsing `/proc/cpuinfo`.
    /// - **Windows**: TODO — uses total processor count as fallback.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let physical = System.Processor.Physical.count
    /// let logical = System.Processor.count
    /// let hasHyperthreading = Int(logical) > Int(physical)
    /// ```
    @inlinable
    public static var count: System.Processor.Count {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        System.Processor.Physical.count
        #elseif os(Linux) || os(Android) || os(OpenBSD)
        System.processorCount
        #elseif os(Windows)
        System.processorCount
        #else
        fatalError("System.Processor.Physical.count: unsupported platform")
        #endif
    }
}
