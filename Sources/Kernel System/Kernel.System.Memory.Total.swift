//
//  System.Memory.Total.swift
//  swift-kernel
//
//  Total installed physical memory — Linux/Windows only.
//
//  On Apple platforms, `swift-darwin`'s `Darwin System` target owns
//  `System.Memory.total` (sysctl "hw.memsize") directly per [PLAT-ARCH-026] /
//  [PLAT-ARCH-028]. swift-kernel MUST NOT also define it there — the duplicate
//  collides with the platform package's definition (re-exported via Kernel) and
//  produces an "ambiguous use of 'total'" error for consumers reading
//  `System.Memory.total` through `import Kernel`.
//
//  NOTE: `swift-linux` / `swift-windows` do not yet own `System.Memory.total`; a
//  precise per-platform implementation (Linux `sysinfo().totalram × mem_unit`,
//  Windows `GlobalMemoryStatusEx`) belongs in their own `System` targets per
//  [PLAT-ARCH-026], at which point this Linux/Windows fallback is removed too.
//

#if os(Linux) || os(Android) || os(OpenBSD) || os(Windows)
extension System.Memory {
    /// Total installed physical memory in bytes.
    @inlinable
    public static var total: System.Memory.Capacity {
        System.Memory.total
    }
}
#endif
