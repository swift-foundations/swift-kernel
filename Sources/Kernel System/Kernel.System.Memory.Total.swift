//
//  System.Memory.Total.swift
//  swift-kernel
//
//  Total installed physical memory — historically an Android/OpenBSD/Windows
//  fallback; retired (F-001, fable-448 remediation, 2026-07-19).
//
//  On Apple platforms, `swift-darwin`'s `Darwin System` target owns
//  `System.Memory.total` (sysctl "hw.memsize") directly per [PLAT-ARCH-026] /
//  [PLAT-ARCH-028]. swift-kernel MUST NOT also define it there — the duplicate
//  collides with the platform package's definition (re-exported via Kernel) and
//  produces an "ambiguous use of 'total'" error for consumers reading
//  `System.Memory.total` through `import Kernel`.
//
//  On Linux, `swift-linux`'s `Linux Kernel System Standard` target owns
//  `System.Memory.total` (/proc/meminfo) directly per [PLAT-ARCH-026]; this
//  fallback was retired for Linux for the same ambiguity reason as Apple above.
//
//  F-001: the Android/OpenBSD/Windows fallback previously defined here read
//
//      public static var total: System.Memory.Capacity { System.Memory.total }
//
//  — a getter that calls itself. There is no base case: every invocation
//  recurses into the same computed property, so any actual call on those
//  three platforms is a guaranteed stack overflow at runtime. Per the
//  finding's proposed end state, the crash-prone fallback is deleted rather
//  than patched: there is no real memory-query implementation to fall back
//  to on these platforms yet (Windows needs `GlobalMemoryStatusEx` via a
//  swift-windows `System` target; Android/OpenBSD need their own per
//  [PLAT-ARCH-026], at which point a real per-platform implementation
//  belongs here instead). Deleting the property turns "compiles, then
//  stack-overflows if called" into "does not compile if referenced" on
//  Android/OpenBSD/Windows — a correct, honest compile-time absence until a
//  real implementation lands, instead of a silent runtime trap.
//
//  `System.Memory.total` remains available on Apple platforms and Linux via
//  the packages named above; it does not exist on Android/OpenBSD/Windows.
//
