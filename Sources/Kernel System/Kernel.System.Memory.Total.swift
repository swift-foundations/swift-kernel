//
//  Kernel.System.Memory.Total.swift
//  swift-kernel
//
//  Cross-platform typed total memory accessor.
//

extension Kernel.System.Memory {
    /// Total installed physical memory in bytes.
    ///
    /// ## Platform Implementation
    ///
    /// - **Darwin**: `sysctl("hw.memsize")`
    /// - **Linux**: `sysinfo().totalram × mem_unit`
    /// - **Windows**: TODO
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let totalRAM = Kernel.System.Memory.total
    /// let gigabytes = UInt64(totalRAM) / (1024 * 1024 * 1024)
    /// ```
    @inlinable
    public static var total: System.Memory.Capacity {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        Darwin.System.Memory.total
        #elseif os(Linux) || os(Android) || os(OpenBSD)
        Linux.System.Memory.total
        #elseif os(Windows)
        Windows.System.Memory.total
        #else
        fatalError("Kernel.System.Memory.total: unsupported platform")
        #endif
    }
}
