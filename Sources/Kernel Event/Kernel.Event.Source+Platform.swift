//
//  Kernel.Event.Source+Platform.swift
//  swift-kernel
//
//  Platform factory for event notification.
//

// MARK: - Platform Default

extension Kernel.Event.Source {
    /// Returns the platform event source.
    ///
    /// - **Darwin**: kqueue
    /// - **Linux**: epoll
    /// - **Windows**: throws `.unsupportedPlatform` (see Direction (iii) note below)
    ///
    /// Throws ``Kernel/Event/Driver/Error/unsupportedPlatform`` if no
    /// event backend is available for the current platform. Consumers
    /// that want graceful fallback to a blocking strategy can catch
    /// this via `try?` and select an alternative.
    ///
    /// ## Windows — Direction (iii) architectural-minimalist disposition
    ///
    /// Per the Tier 5-Windows-Mirror sub-envelope Q4 disposition (2026-05-02),
    /// `Kernel.Event` remains POSIX-only on Windows. The Windows IOCP paradigm
    /// is **proactor-style completion** (the OS reports "I/O finished, here are
    /// the bytes"), not **reactor-style readiness** (the OS reports "the fd is
    /// readable, do the read yourself"). These paradigms are not interchangeable
    /// and bridging them across the cross-platform `Kernel.Event` surface would
    /// either degrade Windows performance or impose a Linux/Darwin-shaped reactor
    /// API on consumers who should be using IOCP directly.
    ///
    /// ## Cross-platform path on Windows
    ///
    /// Cross-platform consumers wanting **proactor-style completion** use
    /// `Kernel.Completion` (the natural home for IOCP — see swift-kernel's
    /// `Kernel Completion` target). Cross-platform consumers wanting
    /// **reactor-style readiness** see `.unsupportedPlatform` here on Windows
    /// and migrate to `Kernel.Completion`. There is no IOCP-to-reactor
    /// bridging layer.
    ///
    /// For Windows-side wakeup of blocked IOCP threads (e.g., for graceful
    /// shutdown of a thread blocked in `GetQueuedCompletionStatusEx`), use
    /// `Windows.\`32\`.Kernel.IO.Completion.Port.wakeup(_:)` — a
    /// signal-closure wrapper around `PostQueuedCompletionStatus` that
    /// composes with `Kernel.Wakeup.Channel(signal:)` for paradigm-agnostic
    /// cross-thread interruption.
    public static func platform() throws(Kernel.Event.Driver.Error) -> Kernel.Event.Source {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            try .kqueue()
        #elseif os(Linux)
            try .epoll()
        #else
            // Windows: Direction (iii) — Kernel.Event is POSIX-only.
            // See doc-comment above for the proactor/reactor paradigm split
            // and the Kernel.Completion migration path for IOCP consumers.
            throw .unsupportedPlatform
        #endif
    }
}
