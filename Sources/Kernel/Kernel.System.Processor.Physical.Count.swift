//
//  Kernel.System.Processor.Physical.Count.swift
//  swift-kernel
//
//  Cross-platform typed physical processor count accessor.
//

extension Kernel.System.Processor.Physical {
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
    /// let physical = Kernel.System.Processor.Physical.count
    /// let logical = Kernel.System.Processor.count
    /// let hasHyperthreading = Int(logical) > Int(physical)
    /// ```
    @inlinable
    public static var count: System.Processor.Count {
        #if canImport(Darwin)
        Darwin.System.Processor.Physical.count
        #elseif canImport(Glibc) || canImport(Musl)
        ISO_9945.Kernel.System.processorCount
        #elseif os(Windows)
        Windows.Kernel.System.processorCount
        #else
        fatalError("Kernel.System.Processor.Physical.count: unsupported platform")
        #endif
    }
}
