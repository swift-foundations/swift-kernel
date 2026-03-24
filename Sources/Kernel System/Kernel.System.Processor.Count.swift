//
//  Kernel.System.Processor.Count.swift
//  swift-kernel
//
//  Cross-platform typed processor count accessor.
//

extension Kernel.System.Processor {
    /// Number of available processors.
    ///
    /// Returns the typed processor count from the platform-specific kernel API.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let threads = Kernel.Thread.Count(Kernel.System.Processor.count)
    /// let lanes = IO.Blocking.Lane.Count(Kernel.System.Processor.count)
    /// ```
    @inlinable
    public static var count: System.Processor.Count {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux) || os(Android) || os(OpenBSD)
        ISO_9945.Kernel.System.processorCount
        #elseif os(Windows)
        Windows.Kernel.System.processorCount
        #else
        fatalError("Kernel.System.Processor.count: unsupported platform")
        #endif
    }
}
