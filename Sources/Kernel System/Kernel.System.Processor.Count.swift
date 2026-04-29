//
//  System.Processor.Count.swift
//  swift-kernel
//
//  Cross-platform typed processor count accessor.
//

extension System.Processor {
    /// Number of available processors.
    ///
    /// Returns the typed processor count from the platform-specific kernel API.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let threads = Kernel.Thread.Count(System.Processor.count)
    /// let lanes = IO.Blocking.Lane.Count(System.Processor.count)
    /// ```
    @inlinable
    public static var count: System.Processor.Count {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux) || os(Android) || os(OpenBSD)
        System.processorCount
        #elseif os(Windows)
        System.processorCount
        #else
        fatalError("System.Processor.count: unsupported platform")
        #endif
    }
}
