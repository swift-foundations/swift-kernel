//
//  Kernel.System.Name.swift
//  swift-kernel
//
//  Cross-platform operating system identification.
//

extension Kernel.System {
    /// Current operating system identification.
    ///
    /// ## Platform Implementation
    ///
    /// - **POSIX** (Darwin, Linux): `uname()` via ISO 9945
    /// - **Windows**: TODO — `RtlGetVersion()`
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let name = Kernel.System.name
    /// print("\(name.system) \(name.release)")  // "Darwin 24.3.0"
    /// ```
    @inlinable
    public static var name: Kernel.System.Name {
        #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
        ISO_9945.Kernel.System.name
        #elseif os(Windows)
        Kernel.System.Name(system: "Windows", release: "unknown", machine: "unknown")
        #else
        fatalError("Kernel.System.name: unsupported platform")
        #endif
    }
}
