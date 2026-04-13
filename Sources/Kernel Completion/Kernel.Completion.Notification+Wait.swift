//
//  Kernel.Completion.Notification+Wait.swift
//  swift-kernel
//
//  Blocking wait for completion notifications.
//

import POSIX_Kernel_File

// MARK: - Blocking Wait

extension Kernel.Completion.Notification {
    /// Blocks until the kernel signals available completions.
    ///
    /// Reads the notification eventfd counter (8-byte blocking read).
    /// Returns when at least one completion event is available for
    /// draining via ``Kernel/Completion/drain(_:)``.
    ///
    /// Best-effort: if the read fails (e.g. EINTR), the caller
    /// should drain again — completions may have arrived.
    public borrowing func wait() {
        var counter: UInt64 = 0
        _ = try? unsafe withUnsafeMutableBytes(of: &counter) { buf in
            try Kernel.IO.Read.read(descriptor, into: buf)
        }
    }
}
